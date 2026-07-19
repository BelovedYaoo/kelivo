import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/assistant_regex.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/sync/config_sync_keys.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

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

final class _ControlledPreferencesStore extends SharedPreferencesStorePlatform {
  _ControlledPreferencesStore(Map<String, Object> values)
    : _values = Map<String, Object>.from(values);

  final Map<String, Object> _values;
  bool failAssistantWrites = false;
  String? failNextSetKey;
  String? failNextRemoveKey;
  void Function()? beforeAssistantWrite;
  bool blockFirstAssistantWrite = false;
  final Completer<void> firstAssistantWriteEntered = Completer<void>();
  final Completer<void> releaseFirstAssistantWrite = Completer<void>();
  int assistantWriteCount = 0;

  @override
  Future<bool> clear() async {
    _values.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async =>
      Map<String, Object>.from(_values);

  @override
  Future<bool> remove(String key) async {
    if (failNextRemoveKey == key) {
      failNextRemoveKey = null;
      return false;
    }
    _values.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.assistants_v1') {
      assistantWriteCount++;
      if (blockFirstAssistantWrite && assistantWriteCount == 1) {
        firstAssistantWriteEntered.complete();
        await releaseFirstAssistantWrite.future;
      }
      beforeAssistantWrite?.call();
      if (failAssistantWrites) return false;
    }
    if (failNextSetKey == key) {
      failNextSetKey = null;
      return false;
    }
    _values[key] = value;
    return true;
  }

  String? get persistedAssistants =>
      _values['flutter.assistants_v1'] as String?;
  String? get persistedCurrentAssistant =>
      _values['flutter.current_assistant_id_v1'] as String?;
}

final class _GateSyncWriteExecutor implements SyncWriteExecutor {
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    return write();
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    return write();
  }
}

final class _GateFirstBatchSyncWriteExecutor implements SyncWriteExecutor {
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();
  final List<List<SyncEntityKey>> batches = <List<SyncEntityKey>>[];

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return write();
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) async {
    batches.add(List<SyncEntityKey>.of(keys));
    if (batches.length == 1) {
      entered.complete();
      await release.future;
    }
    return write();
  }
}

final class _RemoteHeldSyncWriteExecutor implements SyncWriteExecutor {
  final Completer<void> remoteLockEntered = Completer<void>();
  final Completer<void> allowRemoteApply = Completer<void>();
  final Completer<void> localWaitEntered = Completer<void>();
  final Completer<void> _remoteReleased = Completer<void>();
  bool _remoteHeld = false;

  Future<T> runRemote<T>(Future<T> Function() write) async {
    _remoteHeld = true;
    remoteLockEntered.complete();
    await allowRemoteApply.future;
    try {
      return await write();
    } finally {
      _remoteHeld = false;
      _remoteReleased.complete();
    }
  }

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return _runLocal(write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    return _runLocal(write);
  }

  Future<T> _runLocal<T>(Future<T> Function() write) async {
    if (_remoteHeld) {
      if (!localWaitEntered.isCompleted) localWaitEntered.complete();
      await _remoteReleased.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw StateError('assistant_lock_order_deadlock'),
      );
    }
    return write();
  }
}

_ControlledPreferencesStore _preferencesStore({
  required List<Map<String, Object?>> assistants,
  String? currentAssistantId,
}) {
  return _ControlledPreferencesStore({
    'flutter.assistants_v1': jsonEncode(assistants),
    if (currentAssistantId != null)
      'flutter.current_assistant_id_v1': currentAssistantId,
  });
}

Future<AssistantProvider> _loadedProvider({
  required List<Map<String, Object?>> assistants,
  SyncWriteExecutor syncWriteExecutor =
      const UntrackedSyncWriteExecutor.forTests(),
  _ControlledPreferencesStore? preferencesStore,
  String? currentAssistantId,
}) async {
  final effectiveCurrentAssistantId =
      currentAssistantId ??
      (assistants.isEmpty ? null : assistants.first['id'].toString());
  final initialValues = <String, Object>{
    'assistants_v1': jsonEncode(assistants),
    if (effectiveCurrentAssistantId != null)
      'current_assistant_id_v1': effectiveCurrentAssistantId,
  };
  if (preferencesStore == null) {
    SharedPreferences.setMockInitialValues(initialValues);
  } else {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = preferencesStore;
  }

  final provider = AssistantProvider(syncWriteExecutor: syncWriteExecutor);
  await provider.ready;
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;
  late SharedPreferencesStorePlatform previousPreferencesStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_assistant_asset_test_',
    );
    previousPathProvider = PathProviderPlatform.instance;
    previousPreferencesStore = SharedPreferencesStorePlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    await SandboxPathResolver.init();
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previousPreferencesStore;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'copies local assistant avatar and background into managed backup directories',
    () async {
      final provider = await _loadedProvider(
        assistants: const [
          {'id': 'assistant-a', 'name': 'Assistant A'},
        ],
      );

      final externalAvatarDir = Directory(
        p.join(tempDir.path, 'external', 'avatars'),
      );
      final externalImagesDir = Directory(
        p.join(tempDir.path, 'external', 'images'),
      );
      await externalAvatarDir.create(recursive: true);
      await externalImagesDir.create(recursive: true);
      final avatarSource = File(p.join(externalAvatarDir.path, 'avatar.png'));
      final backgroundSource = File(p.join(externalImagesDir.path, 'bg.jpg'));
      await avatarSource.writeAsBytes(const [1, 2, 3], flush: true);
      await backgroundSource.writeAsBytes(const [4, 5, 6], flush: true);

      await provider.updateAssistant(
        provider.assistants.single.copyWith(
          avatar: avatarSource.path,
          background: backgroundSource.path,
        ),
      );

      final updated = provider.assistants.single;
      expect(updated.avatar, isNot(avatarSource.path));
      expect(updated.background, isNot(backgroundSource.path));

      final managedAvatars = p.normalize(p.join(tempDir.path, 'avatars'));
      final managedImages = p.normalize(p.join(tempDir.path, 'images'));
      final avatarPath = p.normalize(updated.avatar!);
      final backgroundPath = p.normalize(updated.background!);

      expect(p.isWithin(managedAvatars, avatarPath), isTrue);
      expect(p.isWithin(managedImages, backgroundPath), isTrue);
      expect(await File(avatarPath).readAsBytes(), const [1, 2, 3]);
      expect(await File(backgroundPath).readAsBytes(), const [4, 5, 6]);
      expect(await avatarSource.exists(), isTrue);
      expect(await backgroundSource.exists(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('assistants_v1')!) as List;
      final storedAssistant = stored.single as Map;
      expect(storedAssistant['avatar'], updated.avatar);
      expect(storedAssistant['background'], updated.background);
    },
  );

  test('复制其他模块的受管资源后不再依赖原模块文件', () async {
    final avatarDirectory = Directory(p.join(tempDir.path, 'avatars'));
    final imageDirectory = Directory(p.join(tempDir.path, 'images'));
    await avatarDirectory.create(recursive: true);
    await imageDirectory.create(recursive: true);
    final userAvatar = File(p.join(avatarDirectory.path, 'avatar_user.png'));
    final providerBackground = File(
      p.join(imageDirectory.path, 'provider_background.jpg'),
    );
    await userAvatar.writeAsBytes(const [1, 2, 3], flush: true);
    await providerBackground.writeAsBytes(const [4, 5, 6], flush: true);
    final provider = await _loadedProvider(
      assistants: const [
        {'id': 'assistant-a', 'name': 'Assistant A'},
      ],
    );

    await provider.updateAssistant(
      provider.assistants.single.copyWith(
        avatar: userAvatar.path,
        background: providerBackground.path,
      ),
    );

    final updated = provider.assistants.single;
    expect(p.equals(updated.avatar!, userAvatar.path), isFalse);
    expect(p.equals(updated.background!, providerBackground.path), isFalse);
    expect(
      p.basename(updated.avatar!),
      matches(
        RegExp(
          r'^assistant_assistant-a_[0-9a-f]{8}-[0-9a-f]{4}-'
          r'[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png$',
        ),
      ),
    );
    expect(
      p.basename(updated.background!),
      matches(
        RegExp(
          r'^background_assistant-a_[0-9a-f]{8}-[0-9a-f]{4}-'
          r'[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$',
        ),
      ),
    );
    await userAvatar.delete();
    await providerBackground.delete();
    expect(await File(updated.avatar!).readAsBytes(), const [1, 2, 3]);
    expect(await File(updated.background!).readAsBytes(), const [4, 5, 6]);
  });

  test('资源复制失败时向上传播且不持久化任何字段', () async {
    final provider = await _loadedProvider(
      assistants: const [
        {'id': 'assistant-a', 'name': 'Assistant A'},
      ],
    );
    final missingSource = p.join(
      tempDir.parent.path,
      'missing-assistant-avatar.png',
    );

    await expectLater(
      provider.updateAssistant(
        provider.assistants.single.copyWith(
          name: 'Assistant Renamed',
          avatar: missingSource,
        ),
      ),
      throwsA(isA<StateError>()),
    );

    final updated = provider.assistants.single;
    expect(updated.name, 'Assistant A');
    expect(updated.avatar, isNull);
    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('assistants_v1')!) as List;
    expect((stored.single as Map)['name'], 'Assistant A');
    expect((stored.single as Map)['avatar'], isNull);
  });

  test('后续资源复制失败时保留旧资源并清理本次新副本', () async {
    final managedAvatarDirectory = Directory(p.join(tempDir.path, 'avatars'));
    await managedAvatarDirectory.create(recursive: true);
    final oldAvatar = File(
      p.join(managedAvatarDirectory.path, 'assistant_old_100.png'),
    );
    await oldAvatar.writeAsBytes(const [1, 2, 3], flush: true);

    final provider = await _loadedProvider(
      assistants: [
        {'id': 'assistant-a', 'name': 'Assistant A', 'avatar': oldAvatar.path},
      ],
    );
    final externalAvatar = File(
      p.join(tempDir.path, 'external', 'replacement.png'),
    );
    await externalAvatar.create(recursive: true);
    await externalAvatar.writeAsBytes(const [4, 5, 6], flush: true);
    final missingBackground = p.join(
      tempDir.parent.path,
      'missing-assistant-background.png',
    );

    await expectLater(
      provider.updateAssistant(
        provider.assistants.single.copyWith(
          name: 'Assistant Renamed',
          avatar: externalAvatar.path,
          background: missingBackground,
        ),
      ),
      throwsA(isA<StateError>()),
    );

    final unchanged = provider.assistants.single;
    expect(unchanged.name, 'Assistant A');
    expect(p.normalize(unchanged.avatar!), p.normalize(oldAvatar.path));
    expect(unchanged.background, isNull);
    expect(await oldAvatar.exists(), isTrue);
    expect(
      await managedAvatarDirectory
          .list()
          .map((entity) => p.normalize(entity.path))
          .toList(),
      [p.normalize(oldAvatar.path)],
    );
  });

  test('锁等待期间列表重排后仍按标识更新目标助手', () async {
    final executor = _GateSyncWriteExecutor();
    final provider = await _loadedProvider(
      assistants: const [
        {'id': 'assistant-a', 'name': 'Assistant A'},
        {'id': 'assistant-b', 'name': 'Assistant B'},
      ],
      syncWriteExecutor: executor,
    );
    final original = provider.getById('assistant-a')!;

    final update = provider.updateAssistant(
      original.copyWith(name: 'Assistant A Updated'),
    );
    await executor.entered.future;
    final reorder = provider.reorderAssistants(0, 1);
    executor.release.complete();
    await Future.wait([update, reorder]);

    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-b',
      'assistant-a',
    ]);
    expect(provider.getById('assistant-a')?.name, 'Assistant A Updated');
    expect(provider.getById('assistant-b')?.name, 'Assistant B');
  });

  test('复制第二项资源失败时回滚列表并清理第一项副本', () async {
    final managedAvatarDirectory = Directory(p.join(tempDir.path, 'avatars'));
    await managedAvatarDirectory.create(recursive: true);
    final sourceAvatar = File(
      p.join(managedAvatarDirectory.path, 'source.png'),
    );
    await sourceAvatar.writeAsBytes(const [1, 2, 3], flush: true);
    final missingBackground = p.join(
      tempDir.parent.path,
      'missing-duplicate-background.png',
    );
    final provider = await _loadedProvider(
      assistants: [
        {
          'id': 'assistant-a',
          'name': 'Assistant A',
          'avatar': sourceAvatar.path,
          'background': missingBackground,
        },
      ],
    );

    await expectLater(
      provider.duplicateAssistant('assistant-a'),
      throwsA(isA<FileSystemException>()),
    );

    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-a',
    ]);
    expect(
      await managedAvatarDirectory
          .list()
          .map((entity) => p.normalize(entity.path))
          .toList(),
      [p.normalize(sourceAvatar.path)],
    );
  });

  test('复制持久化返回失败时回滚列表与两项资源副本', () async {
    final avatarDirectory = Directory(p.join(tempDir.path, 'avatars'));
    final imageDirectory = Directory(p.join(tempDir.path, 'images'));
    await avatarDirectory.create(recursive: true);
    await imageDirectory.create(recursive: true);
    final sourceAvatar = File(p.join(avatarDirectory.path, 'source.png'));
    final sourceBackground = File(p.join(imageDirectory.path, 'source.jpg'));
    await sourceAvatar.writeAsBytes(const [1, 2, 3], flush: true);
    await sourceBackground.writeAsBytes(const [4, 5, 6], flush: true);
    final assistants = <Map<String, Object?>>[
      {
        'id': 'assistant-a',
        'name': 'Assistant A',
        'avatar': sourceAvatar.path,
        'background': sourceBackground.path,
      },
    ];
    final store = _ControlledPreferencesStore({
      'flutter.assistants_v1': jsonEncode(assistants),
      'flutter.current_assistant_id_v1': 'assistant-a',
    });
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failAssistantWrites = true;

    await expectLater(
      provider.duplicateAssistant('assistant-a'),
      throwsA(isA<StateError>()),
    );

    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-a',
    ]);
    expect(
      await avatarDirectory
          .list()
          .map((entity) => p.normalize(entity.path))
          .toList(),
      [p.normalize(sourceAvatar.path)],
    );
    expect(
      await imageDirectory
          .list()
          .map((entity) => p.normalize(entity.path))
          .toList(),
      [p.normalize(sourceBackground.path)],
    );
    expect(
      jsonDecode(store.persistedAssistants!) as List<dynamic>,
      hasLength(1),
    );
  });

  test('更新持久化失败时保留旧资源并清理新副本', () async {
    final avatarDirectory = Directory(p.join(tempDir.path, 'avatars'));
    await avatarDirectory.create(recursive: true);
    final oldAvatar = File(
      p.join(avatarDirectory.path, 'assistant_old_100.png'),
    );
    await oldAvatar.writeAsBytes(const [1, 2, 3], flush: true);
    final replacement = File(
      p.join(tempDir.path, 'external', 'replacement.png'),
    );
    await replacement.create(recursive: true);
    await replacement.writeAsBytes(const [4, 5, 6], flush: true);
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A', 'avatar': oldAvatar.path},
    ];
    final store = _ControlledPreferencesStore({
      'flutter.assistants_v1': jsonEncode(assistants),
      'flutter.current_assistant_id_v1': 'assistant-a',
    });
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failAssistantWrites = true;

    await expectLater(
      provider.updateAssistant(
        provider.assistants.single.copyWith(
          name: 'Assistant A Updated',
          avatar: replacement.path,
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(provider.assistants.single.name, 'Assistant A');
    expect(
      p.normalize(provider.assistants.single.avatar!),
      p.normalize(oldAvatar.path),
    );
    expect(await oldAvatar.exists(), isTrue);
    expect(
      await avatarDirectory
          .list()
          .map((entity) => p.normalize(entity.path))
          .toList(),
      [p.normalize(oldAvatar.path)],
    );
    final prefs = await SharedPreferences.getInstance();
    final cached = jsonDecode(prefs.getString('assistants_v1')!) as List;
    expect((cached.single as Map)['name'], 'Assistant A');
    expect(
      p.normalize((cached.single as Map)['avatar'] as String),
      p.normalize(oldAvatar.path),
    );
  });

  test('更新成功前保留旧资源且成功后清理受管孤儿', () async {
    final avatarDirectory = Directory(p.join(tempDir.path, 'avatars'));
    await avatarDirectory.create(recursive: true);
    final oldAvatar = File(
      p.join(avatarDirectory.path, 'assistant_old_100.png'),
    );
    await oldAvatar.writeAsBytes(const [1, 2, 3], flush: true);
    final replacement = File(
      p.join(tempDir.path, 'external', 'replacement.png'),
    );
    await replacement.create(recursive: true);
    await replacement.writeAsBytes(const [4, 5, 6], flush: true);
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A', 'avatar': oldAvatar.path},
    ];
    final store = _ControlledPreferencesStore({
      'flutter.assistants_v1': jsonEncode(assistants),
      'flutter.current_assistant_id_v1': 'assistant-a',
    });
    var oldResourceExistedDuringPersist = false;
    store.beforeAssistantWrite = () {
      oldResourceExistedDuringPersist = oldAvatar.existsSync();
    };
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );

    await provider.updateAssistant(
      provider.assistants.single.copyWith(avatar: replacement.path),
    );

    expect(oldResourceExistedDuringPersist, isTrue);
    expect(await oldAvatar.exists(), isFalse);
    expect(await File(provider.assistants.single.avatar!).exists(), isTrue);
  });

  test('删除助手成功后清理不再引用的受管资源', () async {
    final avatarDirectory = Directory(p.join(tempDir.path, 'avatars'));
    final imageDirectory = Directory(p.join(tempDir.path, 'images'));
    await avatarDirectory.create(recursive: true);
    await imageDirectory.create(recursive: true);
    final avatar = File(
      p.join(avatarDirectory.path, 'assistant_deleted_100.png'),
    );
    final background = File(
      p.join(imageDirectory.path, 'background_deleted_100.jpg'),
    );
    await avatar.writeAsBytes(const [1, 2, 3], flush: true);
    await background.writeAsBytes(const [4, 5, 6], flush: true);
    final provider = await _loadedProvider(
      assistants: [
        {
          'id': 'assistant-delete',
          'name': 'Delete',
          'avatar': avatar.path,
          'background': background.path,
        },
        {'id': 'assistant-keep', 'name': 'Keep'},
      ],
    );

    expect(await provider.deleteAssistant('assistant-delete'), isTrue);

    expect(await avatar.exists(), isFalse);
    expect(await background.exists(), isFalse);
  });

  test('删除助手时保留仍被其他助手引用的受管资源', () async {
    final avatarDirectory = Directory(p.join(tempDir.path, 'avatars'));
    await avatarDirectory.create(recursive: true);
    final sharedAvatar = File(
      p.join(avatarDirectory.path, 'assistant_shared_100.png'),
    );
    await sharedAvatar.writeAsBytes(const [1, 2, 3], flush: true);
    final provider = await _loadedProvider(
      assistants: [
        {
          'id': 'assistant-delete',
          'name': 'Delete',
          'avatar': sharedAvatar.path,
        },
        {'id': 'assistant-keep', 'name': 'Keep', 'avatar': sharedAvatar.path},
      ],
    );

    expect(await provider.deleteAssistant('assistant-delete'), isTrue);

    expect(await sharedAvatar.exists(), isTrue);
    expect(
      p.normalize(provider.assistants.single.avatar!),
      p.normalize(sharedAvatar.path),
    );
  });

  test('删除助手时保留通过等价受管路径引用的资源', () async {
    final avatarDirectory = Directory(p.join(tempDir.path, 'avatars'));
    final realDirectory = Directory(p.join(avatarDirectory.path, 'real'));
    final aliasDirectoryPath = p.join(avatarDirectory.path, 'alias');
    await realDirectory.create(recursive: true);
    final sharedAvatar = File(
      p.join(realDirectory.path, 'assistant_shared_alias_100.png'),
    );
    await sharedAvatar.writeAsBytes(const [1, 2, 3], flush: true);
    await _createDirectoryLink(aliasDirectoryPath, realDirectory.path);
    final aliasPath = p.join(
      aliasDirectoryPath,
      'assistant_shared_alias_100.png',
    );
    final provider = await _loadedProvider(
      assistants: [
        {
          'id': 'assistant-delete',
          'name': 'Delete',
          'avatar': sharedAvatar.path,
        },
        {'id': 'assistant-keep', 'name': 'Keep'},
      ],
    );
    await provider.syncUpsertAssistant(
      provider.getById('assistant-keep')!.copyWith(avatar: aliasPath),
      position: 1,
    );
    expect(
      await File(provider.getById('assistant-keep')!.avatar!).exists(),
      isTrue,
      reason: provider.getById('assistant-keep')!.avatar,
    );

    expect(await provider.deleteAssistant('assistant-delete'), isTrue);

    expect(await sharedAvatar.exists(), isTrue);
    expect(await File(provider.assistants.single.avatar!).exists(), isTrue);
  });

  test('不同助手并发更新不会让后完成的旧快照覆盖整份配置', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
      {'id': 'assistant-b', 'name': 'Assistant B'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    )..blockFirstAssistantWrite = true;
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );

    final updateA = provider.updateAssistant(
      provider.getById('assistant-a')!.copyWith(name: 'Assistant A Updated'),
    );
    await store.firstAssistantWriteEntered.future;
    final updateB = provider.updateAssistant(
      provider.getById('assistant-b')!.copyWith(name: 'Assistant B Updated'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    store.releaseFirstAssistantWrite.complete();
    await Future.wait([updateA, updateB]);

    expect(provider.getById('assistant-a')?.name, 'Assistant A Updated');
    expect(provider.getById('assistant-b')?.name, 'Assistant B Updated');
    final persisted = jsonDecode(store.persistedAssistants!) as List<dynamic>;
    expect(persisted.map((item) => (item as Map)['name']), const [
      'Assistant A Updated',
      'Assistant B Updated',
    ]);
  });

  test('同一助手的远端实体锁与本地更新交错时不会互相等待', () async {
    final executor = _RemoteHeldSyncWriteExecutor();
    final provider = await _loadedProvider(
      assistants: const [
        {'id': 'assistant-a', 'name': 'Assistant A'},
      ],
      syncWriteExecutor: executor,
    );
    final localAssistant = provider.assistants.single.copyWith(
      name: 'Local Updated',
    );
    final remoteAssistant = provider.assistants.single.copyWith(
      name: 'Remote Updated',
    );

    final remote = executor.runRemote<void>(
      () => provider.syncUpsertAssistant(remoteAssistant, position: 0),
    );
    await executor.remoteLockEntered.future;
    final local = provider.updateAssistant(localAssistant);
    await executor.localWaitEntered.future;
    executor.allowRemoteApply.complete();

    await Future.wait<void>([remote, local]);

    expect(provider.assistants.single.name, 'Local Updated');
  });

  test('远端插入与本地排序交错时仍移动调用时选中的助手', () async {
    final executor = _RemoteHeldSyncWriteExecutor();
    final provider = await _loadedProvider(
      assistants: const [
        {'id': 'assistant-a', 'name': 'Assistant A'},
        {'id': 'assistant-b', 'name': 'Assistant B'},
      ],
      syncWriteExecutor: executor,
    );
    const remoteAssistant = Assistant(id: 'assistant-c', name: 'Assistant C');

    final remote = executor.runRemote<void>(
      () => provider.syncUpsertAssistant(remoteAssistant, position: 0),
    );
    await executor.remoteLockEntered.future;
    final local = provider.reorderAssistants(0, 1);
    await executor.localWaitEntered.future;
    executor.allowRemoteApply.complete();

    await Future.wait<void>([remote, local]);

    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-c',
      'assistant-b',
      'assistant-a',
    ]);
  });

  test('远端调整子集成员与本地子集排序交错时仍按助手身份移动', () async {
    final executor = _RemoteHeldSyncWriteExecutor();
    final provider = await _loadedProvider(
      assistants: const [
        {'id': 'assistant-a', 'name': 'Assistant A'},
        {'id': 'assistant-b', 'name': 'Assistant B'},
        {'id': 'assistant-c', 'name': 'Assistant C'},
      ],
      syncWriteExecutor: executor,
    );
    final remoteAssistant = provider.getById('assistant-c')!;

    final remote = executor.runRemote<void>(
      () => provider.syncUpsertAssistant(remoteAssistant, position: 0),
    );
    await executor.remoteLockEntered.future;
    final local = provider.reorderAssistantsWithin(
      subsetIds: const ['assistant-a', 'assistant-b', 'assistant-c'],
      oldIndex: 0,
      newIndex: 1,
    );
    await executor.localWaitEntered.future;
    executor.allowRemoteApply.complete();

    await Future.wait<void>([remote, local]);

    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-c',
      'assistant-b',
      'assistant-a',
    ]);
  });

  test('远端正则排序与本地排序交错时仍移动调用时选中的规则', () async {
    final executor = _RemoteHeldSyncWriteExecutor();
    const regexA = AssistantRegex(
      id: 'regex-a',
      name: 'Regex A',
      pattern: 'a',
      replacement: 'a',
    );
    const regexB = AssistantRegex(
      id: 'regex-b',
      name: 'Regex B',
      pattern: 'b',
      replacement: 'b',
    );
    const regexC = AssistantRegex(
      id: 'regex-c',
      name: 'Regex C',
      pattern: 'c',
      replacement: 'c',
    );
    final provider = await _loadedProvider(
      assistants: [
        {
          'id': 'assistant-a',
          'name': 'Assistant A',
          'regexRules': [regexA.toJson(), regexB.toJson(), regexC.toJson()],
        },
      ],
      syncWriteExecutor: executor,
    );
    final remoteAssistant = provider.assistants.single.copyWith(
      regexRules: const [regexC, regexA, regexB],
    );

    final remote = executor.runRemote<void>(
      () => provider.syncUpsertAssistant(remoteAssistant, position: 0),
    );
    await executor.remoteLockEntered.future;
    final local = provider.reorderAssistantRegex(
      assistantId: 'assistant-a',
      oldIndex: 0,
      newIndex: 1,
    );
    await executor.localWaitEntered.future;
    executor.allowRemoteApply.complete();

    await Future.wait<void>([remote, local]);

    expect(provider.assistants.single.regexRules.map((rule) => rule.id), const [
      'regex-c',
      'regex-b',
      'regex-a',
    ]);
  });

  test('排队批次会基于前序提交后的最新列表声明实体键', () async {
    final executor = _GateFirstBatchSyncWriteExecutor();
    final provider = await _loadedProvider(
      assistants: const [
        {'id': 'assistant-a', 'name': 'Assistant A'},
        {'id': 'assistant-b', 'name': 'Assistant B'},
        {'id': 'assistant-c', 'name': 'Assistant C'},
      ],
      syncWriteExecutor: executor,
    );

    final reorder = provider.reorderAssistants(0, 2);
    await executor.entered.future;
    final delete = provider.deleteAssistant('assistant-b');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    executor.release.complete();
    await Future.wait<Object?>([reorder, delete]);

    expect(executor.batches, hasLength(2));
    expect(executor.batches.last, [
      ConfigSyncKeys.assistant('assistant-b'),
      ConfigSyncKeys.assistant('assistant-c'),
      ConfigSyncKeys.assistant('assistant-a'),
      ConfigSyncKeys.assistantSelection,
    ]);
    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-c',
      'assistant-a',
    ]);
  });

  test('切换当前助手写入失败时不发布内存且可以重试', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
      {'id': 'assistant-b', 'name': 'Assistant B'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextSetKey = 'flutter.current_assistant_id_v1';

    await expectLater(
      provider.setCurrentAssistant('assistant-b'),
      throwsA(isA<StateError>()),
    );

    expect(provider.currentAssistantId, 'assistant-a');
    expect(store.persistedCurrentAssistant, 'assistant-a');

    await provider.setCurrentAssistant('assistant-b');
    expect(provider.currentAssistantId, 'assistant-b');
    expect(store.persistedCurrentAssistant, 'assistant-b');
  });

  test('清空当前助手删除失败时不发布内存且可以重试', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextRemoveKey = 'flutter.current_assistant_id_v1';

    await expectLater(
      provider.syncSetCurrentAssistant(null),
      throwsA(isA<StateError>()),
    );

    expect(provider.currentAssistantId, 'assistant-a');
    expect(store.persistedCurrentAssistant, 'assistant-a');

    await provider.syncSetCurrentAssistant(null);
    expect(provider.currentAssistantId, isNull);
    expect(store.persistedCurrentAssistant, isNull);
  });

  test('新增助手持久化失败时不发布内存且可以重试', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextSetKey = 'flutter.assistants_v1';

    await expectLater(
      provider.addAssistant(name: 'Assistant B'),
      throwsA(isA<StateError>()),
    );
    expect(provider.assistants.map((assistant) => assistant.name), const [
      'Assistant A',
    ]);

    await provider.addAssistant(name: 'Assistant B');
    expect(provider.assistants.map((assistant) => assistant.name), const [
      'Assistant A',
      'Assistant B',
    ]);
  });

  test('助手搜索开关持久化失败时不发布内存且可以重试', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextSetKey = 'flutter.assistants_v1';

    await expectLater(
      provider.setSearchEnabledForCurrentAssistant(true),
      throwsA(isA<StateError>()),
    );
    expect(provider.currentSearchEnabled, isFalse);

    await provider.setSearchEnabledForCurrentAssistant(true);
    expect(provider.currentSearchEnabled, isTrue);
  });

  test('远端更新助手持久化失败时不发布内存且可以重试', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    final updated = provider.assistants.single.copyWith(
      name: 'Assistant A Synced',
    );
    store.failNextSetKey = 'flutter.assistants_v1';

    await expectLater(
      provider.syncUpsertAssistant(updated, position: 0),
      throwsA(isA<StateError>()),
    );
    expect(provider.assistants.single.name, 'Assistant A');

    await provider.syncUpsertAssistant(updated, position: 0);
    expect(provider.assistants.single.name, 'Assistant A Synced');
  });

  test('远端删除持久化失败后保留助手并允许原操作重试', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
      {'id': 'assistant-b', 'name': 'Assistant B'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextSetKey = 'flutter.assistants_v1';

    await expectLater(
      provider.syncDeleteAssistant('assistant-a'),
      throwsA(isA<StateError>()),
    );
    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-a',
      'assistant-b',
    ]);
    expect(provider.currentAssistantId, 'assistant-a');

    await provider.syncDeleteAssistant('assistant-a');
    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-b',
    ]);
    expect(provider.currentAssistantId, 'assistant-b');
  });

  test('远端删除最后助手时选择删除失败会补偿整份配置', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextRemoveKey = 'flutter.current_assistant_id_v1';

    await expectLater(
      provider.syncDeleteAssistant('assistant-a'),
      throwsA(isA<StateError>()),
    );

    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-a',
    ]);
    expect(provider.currentAssistantId, 'assistant-a');
    final persistedAfterFailure =
        jsonDecode(store.persistedAssistants!) as List<dynamic>;
    expect(persistedAfterFailure.map((item) => (item as Map)['id']), const [
      'assistant-a',
    ]);
    expect(store.persistedCurrentAssistant, 'assistant-a');

    await provider.syncDeleteAssistant('assistant-a');
    expect(provider.assistants, isEmpty);
    expect(provider.currentAssistantId, isNull);
    expect(store.persistedCurrentAssistant, isNull);
  });

  test('助手整体排序持久化失败时不发布内存且可以重试', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
      {'id': 'assistant-b', 'name': 'Assistant B'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextSetKey = 'flutter.assistants_v1';

    await expectLater(
      provider.reorderAssistants(0, 1),
      throwsA(isA<StateError>()),
    );
    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-a',
      'assistant-b',
    ]);

    await provider.reorderAssistants(0, 1);
    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-b',
      'assistant-a',
    ]);
  });

  test('助手子集排序持久化失败时不发布内存且可以重试', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
      {'id': 'assistant-b', 'name': 'Assistant B'},
      {'id': 'assistant-c', 'name': 'Assistant C'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextSetKey = 'flutter.assistants_v1';

    await expectLater(
      provider.reorderAssistantsWithin(
        subsetIds: const ['assistant-a', 'assistant-c'],
        oldIndex: 0,
        newIndex: 1,
      ),
      throwsA(isA<StateError>()),
    );
    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-a',
      'assistant-b',
      'assistant-c',
    ]);

    await provider.reorderAssistantsWithin(
      subsetIds: const ['assistant-a', 'assistant-c'],
      oldIndex: 0,
      newIndex: 1,
    );
    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-c',
      'assistant-b',
      'assistant-a',
    ]);
  });

  test('助手正则排序持久化失败时不发布内存且可以重试', () async {
    final assistants = <Map<String, Object?>>[
      {
        'id': 'assistant-a',
        'name': 'Assistant A',
        'regexRules': [
          const AssistantRegex(
            id: 'regex-a',
            name: 'Regex A',
            pattern: 'a',
            replacement: 'a',
          ).toJson(),
          const AssistantRegex(
            id: 'regex-b',
            name: 'Regex B',
            pattern: 'b',
            replacement: 'b',
          ).toJson(),
        ],
      },
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextSetKey = 'flutter.assistants_v1';

    await expectLater(
      provider.reorderAssistantRegex(
        assistantId: 'assistant-a',
        oldIndex: 0,
        newIndex: 1,
      ),
      throwsA(isA<StateError>()),
    );
    expect(provider.assistants.single.regexRules.map((rule) => rule.id), const [
      'regex-a',
      'regex-b',
    ]);

    await provider.reorderAssistantRegex(
      assistantId: 'assistant-a',
      oldIndex: 0,
      newIndex: 1,
    );
    expect(provider.assistants.single.regexRules.map((rule) => rule.id), const [
      'regex-b',
      'regex-a',
    ]);
  });

  test('删除助手持久化失败时保留内存且可以重试', () async {
    final assistants = <Map<String, Object?>>[
      {'id': 'assistant-a', 'name': 'Assistant A'},
      {'id': 'assistant-b', 'name': 'Assistant B'},
    ];
    final store = _preferencesStore(
      assistants: assistants,
      currentAssistantId: 'assistant-a',
    );
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextSetKey = 'flutter.current_assistant_id_v1';

    await expectLater(
      provider.deleteAssistant('assistant-a'),
      throwsA(isA<StateError>()),
    );
    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-a',
      'assistant-b',
    ]);
    expect(provider.currentAssistantId, 'assistant-a');
    final persistedAfterFailure =
        jsonDecode(store.persistedAssistants!) as List<dynamic>;
    expect(persistedAfterFailure.map((item) => (item as Map)['id']), const [
      'assistant-a',
      'assistant-b',
    ]);
    expect(store.persistedCurrentAssistant, 'assistant-a');

    expect(await provider.deleteAssistant('assistant-a'), isTrue);
    expect(provider.assistants.map((assistant) => assistant.id), const [
      'assistant-b',
    ]);
    expect(provider.currentAssistantId, 'assistant-b');
  });

  testWidgets('默认助手持久化失败时不发布内存且可以重试', (tester) async {
    BuildContext? context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (currentContext) {
            context = currentContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final assistants = <Map<String, Object?>>[];
    final store = _preferencesStore(assistants: assistants);
    final provider = await _loadedProvider(
      assistants: assistants,
      preferencesStore: store,
    );
    store.failNextSetKey = 'flutter.assistants_v1';

    await expectLater(
      provider.ensureDefaults(context!),
      throwsA(isA<StateError>()),
    );
    expect(provider.assistants, isEmpty);
    expect(provider.currentAssistantId, isNull);

    await provider.ensureDefaults(context!);
    expect(provider.assistants, hasLength(2));
    expect(provider.currentAssistantId, provider.assistants.first.id);
  });

  test('删除助手不会清理用户或供应商命名的受管目录文件', () async {
    final avatarDirectory = Directory(p.join(tempDir.path, 'avatars'));
    final imageDirectory = Directory(p.join(tempDir.path, 'images'));
    await avatarDirectory.create(recursive: true);
    await imageDirectory.create(recursive: true);
    final userAvatar = File(p.join(avatarDirectory.path, 'user_avatar.png'));
    final providerBackground = File(
      p.join(imageDirectory.path, 'provider_background.jpg'),
    );
    await userAvatar.writeAsBytes(const [1, 2, 3], flush: true);
    await providerBackground.writeAsBytes(const [4, 5, 6], flush: true);
    final provider = await _loadedProvider(
      assistants: [
        {
          'id': 'assistant-delete',
          'name': 'Delete',
          'avatar': userAvatar.path,
          'background': providerBackground.path,
        },
        {'id': 'assistant-keep', 'name': 'Keep'},
      ],
    );

    expect(await provider.deleteAssistant('assistant-delete'), isTrue);

    expect(await userAvatar.exists(), isTrue);
    expect(await providerBackground.exists(), isTrue);
  });
}

Future<void> _createDirectoryLink(String linkPath, String targetPath) async {
  if (!Platform.isWindows) {
    await Link(linkPath).create(targetPath);
    return;
  }
  final result = await Process.run(
    'pwsh',
    <String>[
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'New-Item -ItemType Junction -Path $env:KELIVO_LINK_PATH '
          r'-Target $env:KELIVO_LINK_TARGET | Out-Null',
    ],
    environment: <String, String>{
      'KELIVO_LINK_PATH': linkPath,
      'KELIVO_LINK_TARGET': targetPath,
    },
  );
  if (result.exitCode != 0) {
    throw StateError('assistant_asset_junction_setup_failed:${result.stderr}');
  }
}
