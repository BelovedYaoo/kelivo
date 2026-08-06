import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/tts/tts_text_selection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';

final class _VaultConfigWriteExecutor implements E2eeConfigVaultWriteExecutor {
  const _VaultConfigWriteExecutor();

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) => Future<T>.sync(write);

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) => Future<T>.sync(write);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and persists TTS playback settings', () async {
    SharedPreferences.setMockInitialValues(const {
      'tts_auto_play_assistant_replies_v1': true,
      'tts_text_selection_mode_v1': 'quotedOnly',
    });

    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await _waitUntil(() => settings.ttsAutoPlayAssistantReplies);

    expect(settings.ttsAutoPlayAssistantReplies, isTrue);
    expect(settings.ttsTextSelectionMode, TtsTextSelectionMode.quotedOnly);

    await settings.setTtsTextSelectionMode(TtsTextSelectionMode.nonItalic);
    await settings.setTtsAutoPlayAssistantReplies(false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tts_text_selection_mode_v1'), 'nonItalic');
    expect(prefs.getBool('tts_auto_play_assistant_replies_v1'), isFalse);
  });

  test('falls back to full text when persisted TTS mode is invalid', () async {
    SharedPreferences.setMockInitialValues(const {
      'tts_auto_play_assistant_replies_v1': true,
      'tts_text_selection_mode_v1': 'unknown-mode',
    });

    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await _waitUntil(() => settings.ttsAutoPlayAssistantReplies);

    expect(settings.ttsTextSelectionMode, TtsTextSelectionMode.fullText);
  });

  test('账户 Vault 模式忽略且不回写明文 TTS 同步偏好', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'tts_auto_play_assistant_replies_v1': true,
      'tts_text_selection_mode_v1': 'quotedOnly',
    });

    final settings = SettingsProvider(
      syncWriteExecutor: const _VaultConfigWriteExecutor(),
    );
    await settings.ready;

    expect(settings.ttsAutoPlayAssistantReplies, isFalse);
    expect(settings.ttsTextSelectionMode, TtsTextSelectionMode.fullText);

    await settings.setTtsAutoPlayAssistantReplies(true);
    await settings.setTtsTextSelectionMode(TtsTextSelectionMode.nonItalic);

    final preferences = await SharedPreferences.getInstance();
    expect(settings.ttsAutoPlayAssistantReplies, isTrue);
    expect(settings.ttsTextSelectionMode, TtsTextSelectionMode.nonItalic);
    expect(preferences.getBool('tts_auto_play_assistant_replies_v1'), isTrue);
    expect(preferences.getString('tts_text_selection_mode_v1'), 'quotedOnly');
  });

  test('账户 Vault 模式忽略且不回写明文全局代理偏好', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'global_proxy_enabled_v1': true,
      'global_proxy_host_v1': 'old.example.com',
      'global_proxy_username_v1': 'old-user',
      'global_proxy_password_v1': 'old-secret',
    });

    final settings = SettingsProvider(
      syncWriteExecutor: const _VaultConfigWriteExecutor(),
    );
    await settings.ready;

    expect(settings.globalProxyEnabled, isFalse);
    expect(settings.globalProxyHost, '');
    expect(settings.globalProxyUsername, '');
    expect(settings.globalProxyPassword, '');

    await settings.setGlobalProxyEnabled(true);
    await settings.setGlobalProxyHost('new.example.com');
    await settings.setGlobalProxyUsername('new-user');
    await settings.setGlobalProxyPassword('new-secret');

    final preferences = await SharedPreferences.getInstance();
    expect(settings.globalProxyEnabled, isTrue);
    expect(settings.globalProxyHost, 'new.example.com');
    expect(settings.globalProxyUsername, 'new-user');
    expect(settings.globalProxyPassword, 'new-secret');
    // 明文介质保持旧值不变，证明 Vault 模式下不落明文。
    expect(preferences.getBool('global_proxy_enabled_v1'), isTrue);
    expect(preferences.getString('global_proxy_host_v1'), 'old.example.com');
    expect(preferences.getString('global_proxy_username_v1'), 'old-user');
    expect(preferences.getString('global_proxy_password_v1'), 'old-secret');
    settings.dispose();
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for SettingsProvider condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
