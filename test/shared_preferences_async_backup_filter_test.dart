import 'dart:convert';

import 'package:Kelivo/core/services/backup/data_sync.dart' as backup_sync;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesAsync backup filter', () {
    test('snapshot excludes local-only settings', () async {
      SharedPreferences.setMockInitialValues({
        'display_chat_font_scale_v1': 1.3,
        'display_auto_scroll_enabled_v1': false,
        'desktop_hotkeys_commands_v1': ['close_window=cmd+w'],
        'desktop_hotkeys_enabled_v1': ['close_window=1'],
        'cloud_sync_base_url_override': 'https://backup.example.com',
      });

      final prefs = await backup_sync.SharedPreferencesAsync.instance;
      final snapshot = await prefs.snapshot();

      expect(snapshot.containsKey('display_chat_font_scale_v1'), isFalse);
      expect(snapshot.containsKey('desktop_hotkeys_commands_v1'), isFalse);
      expect(snapshot.containsKey('desktop_hotkeys_enabled_v1'), isFalse);
      expect(snapshot.containsKey('cloud_sync_base_url_override'), isFalse);
      expect(snapshot['display_auto_scroll_enabled_v1'], isFalse);
    });

    test(
      'regular backup snapshot includes credentials for full restore',
      () async {
        final providerConfigs = jsonEncode({
          'openai': {
            'id': 'openai',
            'apiKey': 'provider-api-secret',
            'baseUrl': 'https://user:provider-url-password@example.com',
          },
        });
        SharedPreferences.setMockInitialValues({
          'provider_configs_v1': providerConfigs,
          'global_proxy_password_v1': 'proxy-secret',
        });

        final prefs = await backup_sync.SharedPreferencesAsync.instance;
        final snapshot = await prefs.snapshotForRegularBackup();

        expect(snapshot['provider_configs_v1'], providerConfigs);
        expect(snapshot['global_proxy_password_v1'], 'proxy-secret');
      },
    );

    test(
      'restore ignores chat font scale but restores synced settings',
      () async {
        SharedPreferences.setMockInitialValues({
          'display_chat_font_scale_v1': 1.15,
          'cloud_sync_base_url_override': 'https://current.example.com',
        });

        final prefs = await backup_sync.SharedPreferencesAsync.instance;
        await prefs.restore({
          'display_chat_font_scale_v1': 1.4,
          'display_auto_scroll_enabled_v1': false,
          'cloud_sync_base_url_override': 'https://backup.example.com',
        });

        final raw = await SharedPreferences.getInstance();
        expect(raw.getDouble('display_chat_font_scale_v1'), 1.15);
        expect(
          raw.getString('cloud_sync_base_url_override'),
          'https://current.example.com',
        );
        expect(raw.getBool('display_auto_scroll_enabled_v1'), isFalse);
      },
    );

    test('restoreSingle ignores old backup chat font scale entries', () async {
      SharedPreferences.setMockInitialValues({
        'display_chat_font_scale_v1': 0.95,
      });

      final prefs = await backup_sync.SharedPreferencesAsync.instance;
      await prefs.restoreSingle('display_chat_font_scale_v1', 1.5);

      final raw = await SharedPreferences.getInstance();
      expect(raw.getDouble('display_chat_font_scale_v1'), 0.95);
    });

    test('restore ignores platform-specific desktop hotkey entries', () async {
      SharedPreferences.setMockInitialValues({
        'desktop_hotkeys_commands_v1': ['close_window=ctrl+w'],
        'desktop_hotkeys_enabled_v1': ['close_window=1'],
      });

      final prefs = await backup_sync.SharedPreferencesAsync.instance;
      await prefs.restore({
        'desktop_hotkeys_commands_v1': ['close_window=cmd+w'],
        'desktop_hotkeys_enabled_v1': ['close_window=0'],
      });

      final raw = await SharedPreferences.getInstance();
      expect(raw.getStringList('desktop_hotkeys_commands_v1'), [
        'close_window=ctrl+w',
      ]);
      expect(raw.getStringList('desktop_hotkeys_enabled_v1'), [
        'close_window=1',
      ]);
    });

    test('restore reports unsupported setting value types', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await backup_sync.SharedPreferencesAsync.instance;
      await expectLater(
        prefs.restore({
          'unsupported_setting': {'nested': true},
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
