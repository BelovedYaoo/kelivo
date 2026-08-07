import 'dart:io';

import 'package:Kelivo/core/services/storage/durable_shared_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:Kelivo/core/services/backup/plaintext_remote_backup_retirement.dart';

const _expectedRetiredPreferenceKeys = <String>{
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
  'providers_order_v1',
  'provider_groups_v1',
  'provider_group_map_v1',
  'provider_ungrouped_position_v1',
  'provider_configs_v1',
  'provider_configs_backup_v1',
  'search_services_v1',
  'search_common_v1',
  'search_selected_v1',
  'search_enabled_v1',
  'search_auto_test_on_launch_v1',
  'tts_services_v1',
  'tts_selected_v1',
  'tts_auto_play_assistant_replies_v1',
  'tts_text_selection_mode_v1',
  'mcp_servers_v1',
  'mcp_request_timeout_ms_v1',
  'assistants_v1',
  'current_assistant_id_v1',
  'user_name',
  'avatar_type',
  'avatar_value',
  'assistant_memories_v1',
  'quick_phrases_v1',
  'world_books_v1',
  'world_books_active_ids_by_assistant_v1',
  'instruction_injections_v1',
  'instruction_injections_active_id_v1',
  'instruction_injections_active_ids_v1',
  'global_proxy_enabled_v1',
  'global_proxy_type_v1',
  'global_proxy_host_v1',
  'global_proxy_port_v1',
  'global_proxy_username_v1',
  'global_proxy_password_v1',
  'global_proxy_bypass_v1',
  'selected_model_v1',
  'title_model_v1',
  'title_prompt_v1',
  'translate_model_v1',
  'translate_prompt_v1',
  'ocr_model_v1',
  'ocr_prompt_v1',
  'summary_model_v1',
  'summary_prompt_v1',
  'suggestion_model_v1',
  'suggestion_prompt_v1',
  'compress_model_v1',
  'compress_prompt_v1',
  'learning_mode_prompt_v1',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('启动入口绑定工作区后以同一 runtime 执行安装级退役', () async {
    final source = await File('lib/main.dart').readAsString();
    const bootstrapCall = 'AccountWorkspaceRuntime.bootstrap(';
    const retirementCall =
        'PlaintextPersistenceRetirement.retireCurrentInstallation(';
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
    expect(
      source.substring(retirementOffset, retirementEnd),
      contains(
        'retirePersistentLogs: installationRootSession.retirePersistentLogs',
      ),
    );
  });

  test('退役键全集覆盖所有已迁入 Vault 的旧明文偏好', () {
    expect(
      PlaintextRemoteBackupRetirement.retiredPreferenceKeys,
      _expectedRetiredPreferenceKeys,
    );
  });

  test('安装级退役精确清除匿名当前及非当前账号旧状态', () async {
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
      for (final key in _expectedRetiredPreferenceKeys) {
        initialPreferences['$prefix$key'] = 'retired';
      }
    }
    initialPreferences.addAll(<String, Object>{
      'flutter.unrelated_preference': 'kept',
      'flutter.webdav_config_v1_extra': 'kept-similar',
      'flutter.provider_group_collapsed_v1': '{"group":true}',
      'flutter.mcp_local_servers_v1': '[]',
      'flutter.migrations_version_v1': 3,
      'flutter.theme_mode_v1': 'dark',
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
    ).retire(localNamespaceIsTruth: false);

    for (final prefix in prefixes) {
      for (final key in _expectedRetiredPreferenceKeys) {
        expect(preferenceStore.containsKey('$prefix$key'), isFalse);
      }
    }
    expect(preferenceStore['flutter.unrelated_preference'], 'kept');
    expect(preferenceStore['flutter.webdav_config_v1_extra'], 'kept-similar');
    expect(
      preferenceStore['flutter.provider_group_collapsed_v1'],
      '{"group":true}',
    );
    expect(preferenceStore['flutter.mcp_local_servers_v1'], '[]');
    expect(preferenceStore['flutter.migrations_version_v1'], 3);
    expect(preferenceStore['flutter.theme_mode_v1'], 'dark');
    expect(preferenceStore['other.app.webdav_config_v1'], 'kept-other-app');
    expect(retirementCalls, 1);
  });

  test('本地工作区退役不删除本地前缀的真相键', () async {
    const activeWorkspaceKey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const prefixes = <String>{
      'flutter.',
      'kelivo.account.$activeWorkspaceKey.',
    };
    final initialPreferences = <String, Object>{};
    for (final prefix in prefixes) {
      for (final key in _expectedRetiredPreferenceKeys) {
        initialPreferences['$prefix$key'] = 'retired';
      }
    }
    initialPreferences.addAll(<String, Object>{
      'flutter.unrelated_preference': 'kept',
      'flutter.theme_mode_v1': 'dark',
    });
    final preferenceStore = _MemoryPlaintextRemoteBackupPreferenceStore(
      initialPreferences,
    );
    var retirementCalls = 0;

    await PlaintextRemoteBackupRetirement(
      preferenceStore: preferenceStore,
      registeredPreferencePrefixes: prefixes,
      retirePlaintextBackups: () async => retirementCalls += 1,
    ).retire(localNamespaceIsTruth: true);

    // 本地工作区没有 E2EE Vault：本地前缀下的助手/供应商等键是唯一真相，
    // 不得当作明文镜像删除。
    for (final key in _expectedRetiredPreferenceKeys) {
      expect(
        preferenceStore.containsKey('flutter.$key'),
        isTrue,
        reason: '本地前缀键 $key 不应被退役',
      );
    }
    // 账号命名空间仍是明文镜像，照旧移除。
    for (final key in _expectedRetiredPreferenceKeys) {
      expect(
        preferenceStore.containsKey('kelivo.account.$activeWorkspaceKey.$key'),
        isFalse,
      );
    }
    expect(preferenceStore['flutter.unrelated_preference'], 'kept');
    expect(preferenceStore['flutter.theme_mode_v1'], 'dark');
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
      ).retire(localNamespaceIsTruth: false),
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
      <String, Object>{'flutter.provider_configs_v1': 'secret'},
      removeSucceeds: false,
    );
    var retirementCalled = false;

    await expectLater(
      PlaintextRemoteBackupRetirement(
        preferenceStore: preferenceStore,
        registeredPreferencePrefixes: const <String>{'flutter.'},
        retirePlaintextBackups: () async => retirementCalled = true,
      ).retire(localNamespaceIsTruth: false),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'plaintext_remote_backup_preference_retirement:'
              'flutter.provider_configs_v1',
        ),
      ),
    );

    expect(preferenceStore.containsKey('flutter.provider_configs_v1'), isTrue);
    expect(retirementCalled, isFalse);
  });

  test('安装级退役重复执行保持幂等且不重复删除', () async {
    final preferenceStore = _MemoryPlaintextRemoteBackupPreferenceStore(
      <String, Object>{'flutter.provider_configs_v1': 'secret'},
    );
    var retirementCalls = 0;
    final retirement = PlaintextRemoteBackupRetirement(
      preferenceStore: preferenceStore,
      registeredPreferencePrefixes: const <String>{'flutter.'},
      retirePlaintextBackups: () async => retirementCalls += 1,
    );

    await retirement.retire(localNamespaceIsTruth: false);
    await retirement.retire(localNamespaceIsTruth: false);

    expect(preferenceStore.containsKey('flutter.provider_configs_v1'), isFalse);
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
      ).retire(localNamespaceIsTruth: false),
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
      ).retire(localNamespaceIsTruth: false),
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
  Future<DurableSharedPreferencesRemovalSession> beginRemoval(
    String rawKey,
  ) async => const _TestSharedPreferencesRemovalSession();
}

final class _TestSharedPreferencesRemovalSession
    implements DurableSharedPreferencesRemovalSession {
  const _TestSharedPreferencesRemovalSession();

  @override
  Future<void> confirmRemoval() async {}

  @override
  Future<void> close() async {}
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
