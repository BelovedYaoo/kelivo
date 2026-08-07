import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path_provider/path_provider.dart';

import '../storage/durable_shared_preferences_store.dart';
import '../workspace/account_workspace_runtime.dart';

final class PlaintextPersistenceRetirement {
  const PlaintextPersistenceRetirement._();

  static Future<void> retireCurrentInstallation({
    required AccountWorkspaceRuntime workspaceRuntime,
    required Future<void> Function() retirePersistentLogs,
  }) async {
    await PlaintextRemoteBackupRetirement.retireCurrentInstallation(
      workspaceRuntime: workspaceRuntime,
    );
    await workspaceRuntime.discardPlaintextLocalState(
      retirePersistentLogs: retirePersistentLogs,
    );
  }
}

final class PlaintextRemoteBackupRetirement {
  const PlaintextRemoteBackupRetirement({
    required this.preferenceStore,
    required this.registeredPreferencePrefixes,
    required this.retirePlaintextBackups,
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
    // 账号模式只信任 E2EE Vault，旧镜像即使不再读取也必须从介质上移除。
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
    // 助手、用户、记忆、快捷短语、世界书、指令注入的旧明文镜像。
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
    // 全局代理随本改动迁入 E2EE Vault，旧明文镜像一并退役。
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

  static const _localPreferencePrefix = 'flutter.';
  static const _accountPreferencePrefix = 'kelivo.account.';
  static final _workspaceKeyPattern = RegExp(r'^[0-9a-f]{64}$');

  final DurableSharedPreferencesStore preferenceStore;
  final Set<String> registeredPreferencePrefixes;
  final Future<void> Function() retirePlaintextBackups;

  static Future<void> retireCurrentInstallation({
    required AccountWorkspaceRuntime workspaceRuntime,
  }) async {
    final registeredPreferencePrefixes = await workspaceRuntime
        .registeredPreferencesPrefixes();
    final temporaryDirectory = await getTemporaryDirectory();
    final temporaryRootSession = await const KelivoSecureCore()
        .openTemporaryRoot(temporaryDirectory.path);
    try {
      await PlaintextRemoteBackupRetirement(
        preferenceStore:
            PlatformDurableSharedPreferencesStore.forCurrentPlatform(),
        registeredPreferencePrefixes: registeredPreferencePrefixes,
        retirePlaintextBackups: temporaryRootSession.retirePlaintextBackups,
      ).retire(localNamespaceIsTruth: workspaceRuntime.current.isLocal);
    } finally {
      await temporaryRootSession.close();
    }
  }

  Future<void> retire({required bool localNamespaceIsTruth}) async {
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
    // 本地工作区没有 E2EE Vault，本地前缀下的键（助手、MCP 等）就是唯一真相，
    // 不能当作"明文镜像"删除；只有账号工作区（配置真相在 Vault）才需要
    // 把介质上的明文镜像一并移除。
    final retiredRawKeys = <String>{
      for (final prefix in registeredPreferencePrefixes)
        if (!localNamespaceIsTruth || prefix != _localPreferencePrefix)
          for (final key in retiredPreferenceKeys) '$prefix$key',
    };
    final existingRetiredKeys =
        existingKeys.where(retiredRawKeys.contains).toList()..sort();
    for (final rawKey in existingRetiredKeys) {
      await preferenceStore.remove(rawKey);
    }
    await retirePlaintextBackups();
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
}
