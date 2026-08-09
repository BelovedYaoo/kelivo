import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'business SharedPreferences access stays inside the frozen allowlist',
    () async {
      // E2EE 版未采用上游 SQLite 业务迁移：本地工作区配置（助手/会话/MCP/
      // stores/备份导入恢复）以 SharedPreferences 为真相源。白名单 = 当前
      // 全量合法访问者；新增访问必须显式加入并说明理由，防止意外泄漏。
      const allowed = <String>{
        'lib/core/providers/assistant_provider.dart',
        'lib/core/providers/chat_provider.dart',
        'lib/core/providers/hotkey_provider.dart',
        'lib/core/providers/instruction_injection_group_provider.dart',
        'lib/core/providers/mcp_provider.dart',
        'lib/core/providers/settings_provider.dart',
        'lib/core/providers/tag_provider.dart',
        'lib/core/providers/tts_provider.dart',
        'lib/core/providers/user_provider.dart',
        'lib/core/services/backup/chatbox_importer.dart',
        'lib/core/services/backup/cherry_importer.dart',
        'lib/core/services/backup/data_sync.dart',
        'lib/core/services/backup/restore_cutover_executor.dart',
        'lib/core/services/backup/restore_settings_store.dart',
        'lib/core/services/backup/restore_startup_gate.dart',
        'lib/core/services/instruction_injection_store.dart',
        'lib/core/services/learning_mode_store.dart',
        'lib/core/services/memory_store.dart',
        'lib/core/services/quick_phrase_store.dart',
        'lib/core/services/workspace/account_workspace_runtime.dart',
        'lib/core/services/world_book_store.dart',
        'lib/desktop/window_size_manager.dart',
        'lib/features/home/services/file_upload_service.dart',
      };
      final references = <String>[];
      await for (final entity in Directory('lib').list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = await entity.readAsString();
        if (!source.contains('package:shared_preferences/') &&
            !RegExp(r'\bSharedPreferences\b').hasMatch(source)) {
          continue;
        }
        references.add(entity.path.replaceAll('\\', '/'));
      }
      references.sort();

      expect(references, orderedEquals(allowed.toList()..sort()));
    },
  );

  test(
    'discarded chat preference keys only exist in the routing filter',
    () async {
      final references = <String>[];
      await for (final entity in Directory('lib').list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = await entity.readAsString();
        if (!source.contains('pinned_chat_ids') &&
            !source.contains('chat_titles_map')) {
          continue;
        }
        references.add(entity.path.replaceAll('\\', '/'));
      }
      references.sort();

      expect(references, <String>[
        'lib/core/database/business_settings_router.dart',
        // E2EE 本地工作区以 prefs 存固定会话与标题（非账号同步配置）。
        'lib/core/providers/chat_provider.dart',
      ]);
    },
  );
}
