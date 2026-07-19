import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';

const _fixtureFontPath =
    'dependencies/gpt_markdown/lib/fonts/JetBrainsMono-Regular.ttf';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

Future<File> _fixtureFontFile() async {
  final file = File(_fixtureFontPath);
  if (!await file.exists()) {
    fail('Missing test font fixture: $_fixtureFontPath');
  }
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider local font persistence', () {
    late PathProviderPlatform previousPathProvider;
    late Directory tempDir;

    setUp(() async {
      previousPathProvider = PathProviderPlatform.instance;
      tempDir = await Directory.systemTemp.createTemp('kelivo_font_test_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      await SandboxPathResolver.init();
    });

    tearDown(() async {
      PathProviderPlatform.instance = previousPathProvider;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('local font import stores managed copy path', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await settings.ready;

      final sourceFile = await _fixtureFontFile();

      await settings.setAppFontFromLocal(path: sourceFile.path);

      final prefs = await SharedPreferences.getInstance();
      final storedPath = prefs.getString('display_app_font_local_path_v1');
      expect(storedPath, isNotNull);
      expect(
        p.isWithin(
          p.normalize(p.join(tempDir.path, 'fonts')),
          p.normalize(storedPath!),
        ),
        isTrue,
      );
      expect(await File(storedPath).exists(), isTrue);
      expect(storedPath, isNot(sourceFile.path));
      expect(prefs.getString('display_app_font_local_alias_v1'), isNotEmpty);
    });

    test(
      'font mutation waits until initial local font reload finishes',
      () async {
        final missingPath = p.join(tempDir.path, 'fonts', 'missing.ttf');
        final store = _BlockingFontReloadPreferenceStore(<String, Object>{
          'flutter.display_app_font_family_v1': 'kelivo_local_app_stale',
          'flutter.display_app_font_is_google_v1': false,
          'flutter.display_app_font_local_path_v1': missingPath,
          'flutter.display_app_font_local_alias_v1': 'kelivo_local_app_stale',
        });
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = store;
        final settings = SettingsProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        );
        await store.firstTargetMutationEntered;

        var mutationCompleted = false;
        final mutation = settings.setAppFontSystemFamily('Arial').then((_) {
          mutationCompleted = true;
        });
        // 让当前微任务队列排空即可判断是否越过 ready，无需依赖机器速度。
        await Future<void>(() {});

        expect(store.targetMutationCount, 1);
        expect(mutationCompleted, isFalse);

        store.releaseFirstTargetMutation();
        await Future.wait(<Future<void>>[settings.ready, mutation]);
        expect(settings.appFontFamily, 'Arial');
      },
    );

    test('replacing local font removes previous managed copy', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await settings.ready;
      final sourceFile = await _fixtureFontFile();

      await settings.setAppFontFromLocal(path: sourceFile.path);
      final prefs = await SharedPreferences.getInstance();
      final firstPath = prefs.getString('display_app_font_local_path_v1');
      expect(firstPath, isNotNull);
      expect(await File(firstPath!).exists(), isTrue);

      await settings.setAppFontFromLocal(path: sourceFile.path);
      final secondPath = prefs.getString('display_app_font_local_path_v1');
      expect(secondPath, isNotNull);
      expect(secondPath, isNot(firstPath));
      expect(await File(secondPath!).exists(), isTrue);
      expect(await File(firstPath).exists(), isFalse);
    });

    test(
      'local font persistence failure keeps previous selection and removes new copy',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        );
        await settings.ready;
        final sourceFile = await _fixtureFontFile();
        await settings.setAppFontFromLocal(path: sourceFile.path);
        final preferences = await SharedPreferences.getInstance();
        final previousPath = preferences.getString(
          'display_app_font_local_path_v1',
        )!;
        final previousFamily = settings.appFontFamily;
        SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
          _physicalPreferenceData(preferences),
          failSetKeySuffix: 'display_app_font_local_path_v1',
        );

        await expectLater(
          settings.setAppFontFromLocal(path: sourceFile.path),
          throwsA(isA<StateError>()),
        );

        expect(settings.appFontFamily, previousFamily);
        expect(await File(previousPath).exists(), isTrue);
        final fonts = Directory(p.join(tempDir.path, 'fonts'));
        expect(
          await fonts
              .list()
              .where((entry) => entry is File)
              .map((entry) => p.normalize(entry.path))
              .toList(),
          <String>[p.normalize(previousPath)],
        );
        await preferences.reload();
        expect(
          p.normalize(preferences.getString('display_app_font_local_path_v1')!),
          p.normalize(previousPath),
        );
      },
    );

    test(
      'font remove failure keeps local selection and managed copy',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        );
        await settings.ready;
        final sourceFile = await _fixtureFontFile();
        await settings.setAppFontFromLocal(path: sourceFile.path);
        final preferences = await SharedPreferences.getInstance();
        final previousPath = preferences.getString(
          'display_app_font_local_path_v1',
        )!;
        final previousFamily = settings.appFontFamily;
        SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
          _physicalPreferenceData(preferences),
          failRemoveKeySuffix: 'display_app_font_local_path_v1',
        );

        await expectLater(
          settings.setAppFontSystemFamily('Arial'),
          throwsA(isA<StateError>()),
        );

        expect(settings.appFontFamily, previousFamily);
        expect(await File(previousPath).exists(), isTrue);
        await preferences.reload();
        expect(
          p.normalize(preferences.getString('display_app_font_local_path_v1')!),
          p.normalize(previousPath),
        );
      },
    );

    test(
      'switching local fonts to system Google or empty selection removes orphaned copies',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        );
        await settings.ready;
        final sourceFile = await _fixtureFontFile();

        await settings.setAppFontFromLocal(path: sourceFile.path);
        final systemReplacedPath = (await SharedPreferences.getInstance())
            .getString('display_app_font_local_path_v1')!;
        await settings.setAppFontSystemFamily('Arial');
        expect(await File(systemReplacedPath).exists(), isFalse);

        await settings.setAppFontFromLocal(path: sourceFile.path);
        final googleReplacedPath = (await SharedPreferences.getInstance())
            .getString('display_app_font_local_path_v1')!;
        await settings.setAppFontFromGoogle('Roboto');
        expect(await File(googleReplacedPath).exists(), isFalse);

        await settings.setCodeFontFromLocal(path: sourceFile.path);
        final clearedPath = (await SharedPreferences.getInstance()).getString(
          'display_code_font_local_path_v1',
        )!;
        await settings.clearCodeFont();
        expect(await File(clearedPath).exists(), isFalse);
      },
    );

    test(
      'clearing one font keeps a managed copy referenced by an equivalent code-font path',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        );
        await settings.ready;
        final sourceFile = await _fixtureFontFile();

        await settings.setAppFontFromLocal(path: sourceFile.path);
        final prefs = await SharedPreferences.getInstance();
        final appPath = prefs.getString('display_app_font_local_path_v1');
        expect(appPath, isNotNull);
        final sharedPath = appPath!;
        final appFamily = prefs.getString('display_app_font_family_v1')!;
        final appAlias = prefs.getString('display_app_font_local_alias_v1')!;
        final equivalentSharedPath = _equivalentPath(sharedPath);

        SharedPreferences.setMockInitialValues({
          'display_app_font_family_v1': appFamily,
          'display_app_font_is_google_v1': false,
          'display_app_font_local_path_v1': sharedPath,
          'display_app_font_local_alias_v1': appAlias,
          'display_code_font_family_v1': 'kelivo_local_code_123',
          'display_code_font_is_google_v1': false,
          'display_code_font_local_path_v1': equivalentSharedPath,
          'display_code_font_local_alias_v1': 'kelivo_local_code_123',
        });
        final sharedSettings = SettingsProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        );
        await sharedSettings.ready;

        await sharedSettings.clearAppFont();

        expect(await File(sharedPath).exists(), isTrue);
      },
    );

    test('failed local font registration removes imported copy', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await settings.ready;
      final invalidFont = File('${tempDir.path}/invalid.ttf');
      await invalidFont.writeAsString('not a font');

      await settings.setAppFontFromLocal(path: invalidFont.path);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('display_app_font_local_path_v1'), isNull);
      final fontsDir = Directory('${tempDir.path}/fonts');
      final entries = await fontsDir.exists()
          ? await fontsDir.list().toList()
          : const <FileSystemEntity>[];
      expect(entries, isEmpty);
    });

    test(
      'font write failure removes the partially written managed copy',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider.forTesting(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
          managedFileWrite: (destination, bytes) async {
            await destination.writeAsBytes(
              bytes.take(32).toList(growable: false),
              flush: true,
            );
            throw FileSystemException('模拟字体写入中途失败', destination.path);
          },
        );
        await settings.ready;
        final sourceFile = await _fixtureFontFile();

        await expectLater(
          settings.setAppFontFromLocal(path: sourceFile.path),
          throwsA(isA<FileSystemException>()),
        );

        final fontsDir = Directory(p.join(tempDir.path, 'fonts'));
        expect(await fontsDir.list().toList(), isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('display_app_font_local_path_v1'), isNull);
      },
    );

    test('invalid persisted local font does not expose stale alias', () async {
      SharedPreferences.setMockInitialValues({
        'display_app_font_family_v1': 'kelivo_local_app_123',
        'display_app_font_is_google_v1': false,
        'display_app_font_local_path_v1':
            '/var/mobile/Containers/Data/Application/OLD/Documents/fonts/missing.ttf',
        'display_app_font_local_alias_v1': 'kelivo_local_app_123',
      });

      final settings = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await settings.ready;

      expect(settings.appFontLocalAlias, isNull);
      expect(settings.appFontFamily, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('display_app_font_local_alias_v1'), isNull);
      expect(prefs.getString('display_app_font_local_path_v1'), isNull);
    });

    test('persisted iOS sandbox font path is remapped on reload', () async {
      final sourceFile = await _fixtureFontFile();

      final fontsDir = Directory('${tempDir.path}/fonts');
      await fontsDir.create(recursive: true);
      final currentFont = File('${fontsDir.path}/SFNS.ttf');
      await currentFont.writeAsBytes(await sourceFile.readAsBytes());
      await SandboxPathResolver.init();

      SharedPreferences.setMockInitialValues({
        'display_app_font_family_v1': 'kelivo_local_app_123',
        'display_app_font_is_google_v1': false,
        'display_app_font_local_path_v1':
            '/var/mobile/Containers/Data/Application/OLD/Documents/fonts/SFNS.ttf',
        'display_app_font_local_alias_v1': 'kelivo_local_app_123',
      });

      final settings = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await settings.ready;

      expect(settings.appFontLocalAlias, isNotEmpty);
      expect(settings.appFontFamily, settings.appFontLocalAlias);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('display_app_font_local_path_v1'),
        currentFont.path,
      );
    });
  });
}

String _equivalentPath(String path) {
  final equivalentBasename = Platform.isWindows
      ? p.basename(path).toUpperCase()
      : p.basename(path);
  final withParentSegment =
      '${p.dirname(path)}${p.separator}.${p.separator}$equivalentBasename';
  return Platform.isWindows
      ? withParentSegment.replaceAll('\\', '/')
      : withParentSegment;
}

final class _BlockingFontReloadPreferenceStore
    extends InMemorySharedPreferencesStore {
  _BlockingFontReloadPreferenceStore(super.data) : super.withData();

  final Completer<void> _firstTargetMutationEntered = Completer<void>();
  final Completer<void> _releaseFirstTargetMutation = Completer<void>();
  var targetMutationCount = 0;

  Future<void> get firstTargetMutationEntered =>
      _firstTargetMutationEntered.future;

  void releaseFirstTargetMutation() {
    if (!_releaseFirstTargetMutation.isCompleted) {
      _releaseFirstTargetMutation.complete();
    }
  }

  Future<void> _beforeMutation(String key) async {
    if (!key.endsWith('display_app_font_family_v1')) return;
    targetMutationCount++;
    if (targetMutationCount != 1) return;
    _firstTargetMutationEntered.complete();
    await _releaseFirstTargetMutation.future;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await _beforeMutation(key);
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    await _beforeMutation(key);
    return super.remove(key);
  }
}

final class _FailingPreferenceStore extends InMemorySharedPreferencesStore {
  _FailingPreferenceStore(
    super.data, {
    this.failSetKeySuffix,
    this.failRemoveKeySuffix,
  }) : super.withData();

  final String? failSetKeySuffix;
  final String? failRemoveKeySuffix;
  var _setFailed = false;
  var _removeFailed = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!_setFailed &&
        failSetKeySuffix != null &&
        key.endsWith(failSetKeySuffix!)) {
      _setFailed = true;
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (!_removeFailed &&
        failRemoveKeySuffix != null &&
        key.endsWith(failRemoveKeySuffix!)) {
      _removeFailed = true;
      return false;
    }
    return super.remove(key);
  }
}

Map<String, Object> _physicalPreferenceData(SharedPreferences preferences) {
  return <String, Object>{
    for (final key in preferences.getKeys())
      if (preferences.get(key) case final Object value) 'flutter.$key': value,
  };
}
