import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';

Future<void> _waitForSettingsLoad() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

ProviderConfig _configWithModels() {
  return ProviderConfig(
    id: 'TestProvider',
    enabled: true,
    name: 'Test Provider',
    apiKey: 'test-key',
    baseUrl: 'https://example.test',
    models: const ['keep', 'remove-a', 'remove-b'],
    modelOverrides: const {
      'keep': {'name': 'Keep'},
      'remove-a': {'name': 'Remove A'},
      'remove-b': {'name': 'Remove B'},
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider model deletion', () {
    test('deleteModels removes selected models and their overrides', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );

      await _waitForSettingsLoad();
      await settings.setProviderConfig('TestProvider', _configWithModels());

      final deleted = await settings.deleteModels('TestProvider', const {
        'remove-a',
        'remove-b',
      });

      final cfg = settings.getProviderConfig('TestProvider');
      expect(deleted, 2);
      expect(cfg.models, const ['keep']);
      expect(cfg.modelOverrides.keys, const ['keep']);
    });

    test('deleteModels does nothing for empty selection', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );

      await _waitForSettingsLoad();
      await settings.setProviderConfig('TestProvider', _configWithModels());

      final deleted = await settings.deleteModels(
        'TestProvider',
        const <String>{},
      );

      final cfg = settings.getProviderConfig('TestProvider');
      expect(deleted, 0);
      expect(cfg.models, const ['keep', 'remove-a', 'remove-b']);
      expect(cfg.modelOverrides.keys, const ['keep', 'remove-a', 'remove-b']);
    });

    test('deleteModels clears selections for deleted models only', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );

      await _waitForSettingsLoad();
      await settings.setProviderConfig('TestProvider', _configWithModels());
      await settings.setCurrentModel('TestProvider', 'remove-a');
      await settings.setTitleModel('TestProvider', 'keep');
      await settings.setTranslateModel('TestProvider', 'remove-a');
      await settings.setOcrModel('TestProvider', 'remove-a');
      await settings.setOcrEnabled(true);
      await settings.setSummaryModel('TestProvider', 'remove-a');
      await settings.setSuggestionModel('TestProvider', 'remove-a');
      await settings.setCompressModel('TestProvider', 'remove-a');
      await settings.togglePinModel('TestProvider', 'remove-a');

      final deleted = await settings.deleteModels('TestProvider', const {
        'remove-a',
      });

      expect(deleted, 1);
      expect(settings.currentModelProvider, isNull);
      expect(settings.currentModelId, isNull);
      expect(settings.titleModelProvider, 'TestProvider');
      expect(settings.titleModelId, 'keep');
      expect(settings.translateModelProvider, isNull);
      expect(settings.translateModelId, isNull);
      expect(settings.ocrModelProvider, isNull);
      expect(settings.ocrModelId, isNull);
      expect(settings.ocrEnabled, isFalse);
      expect(settings.summaryModelProvider, isNull);
      expect(settings.summaryModelId, isNull);
      expect(settings.suggestionModelProvider, isNull);
      expect(settings.suggestionModelId, isNull);
      expect(settings.compressModelProvider, isNull);
      expect(settings.compressModelId, isNull);
      expect(settings.isModelPinned('TestProvider', 'remove-a'), isFalse);
    });

    test(
      'deleteModels clears orphan overrides when every model is removed',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        );

        await _waitForSettingsLoad();
        await settings.setProviderConfig(
          'TestProvider',
          _configWithModels().copyWith(
            modelOverrides: const {
              'keep': {'name': 'Keep'},
              'remove-a': {'name': 'Remove A'},
              'remove-b': {'name': 'Remove B'},
              'orphan': {'name': 'Orphan'},
            },
          ),
        );

        final deleted = await settings.deleteModels('TestProvider', const {
          'keep',
          'remove-a',
          'remove-b',
        });

        final cfg = settings.getProviderConfig('TestProvider');
        expect(deleted, 3);
        expect(cfg.models, isEmpty);
        expect(cfg.modelOverrides, isEmpty);
      },
    );
  });
}
