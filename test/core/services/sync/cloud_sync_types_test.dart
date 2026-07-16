import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/quick_phrase.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/config_sync_adapter.dart';
import 'package:Kelivo/core/services/sync/config_sync_keys.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';

final class _RecordingSyncWriteExecutor implements SyncWriteExecutor {
  final List<List<SyncEntityKey>> batches = <List<SyncEntityKey>>[];
  bool rejectWrites = false;
  Set<String>? _activeStorageKeys;

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return runLocalBatch(keys: <SyncEntityKey>[key], write: write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) async {
    final batch = List<SyncEntityKey>.unmodifiable(keys);
    final active = _activeStorageKeys;
    if (active != null) {
      final missing = batch
          .where((key) => !active.contains(key.storageKey))
          .toList(growable: false);
      if (missing.isNotEmpty) {
        throw StateError('嵌套写入缺少外层声明：$missing');
      }
      return write();
    }
    batches.add(batch);
    if (rejectWrites) throw StateError('拒绝测试写入');
    _activeStorageKeys = batch.map((key) => key.storageKey).toSet();
    try {
      return await write();
    } finally {
      _activeStorageKeys = null;
    }
  }
}

Future<
  ({
    ConfigSyncAdapter adapter,
    McpProvider mcp,
    SettingsProvider settings,
    UserProvider user,
  })
>
_createConfigFixture(_RecordingSyncWriteExecutor writes) async {
  final settings = SettingsProvider(syncWriteExecutor: writes);
  final assistants = AssistantProvider(syncWriteExecutor: writes);
  final memories = MemoryProvider(syncWriteExecutor: writes);
  final mcp = McpProvider(syncWriteExecutor: writes);
  final quickPhrases = QuickPhraseProvider(syncWriteExecutor: writes);
  final injections = InstructionInjectionProvider(syncWriteExecutor: writes);
  final worldBooks = WorldBookProvider(syncWriteExecutor: writes);
  final user = UserProvider(syncWriteExecutor: writes);
  final adapter = ConfigSyncAdapter(
    settingsProvider: settings,
    assistantProvider: assistants,
    memoryProvider: memories,
    mcpProvider: mcp,
    quickPhraseProvider: quickPhrases,
    instructionInjectionProvider: injections,
    worldBookProvider: worldBooks,
    userProvider: user,
  );
  await adapter.ready;
  return (adapter: adapter, mcp: mcp, settings: settings, user: user);
}

RemoteSyncEntity _profileEntity(Map<String, Object?> payload) {
  return RemoteSyncEntity(
    entityType: ConfigSyncKeys.preferenceType,
    entityId: ConfigSyncKeys.profile.entityId,
    revision: 1,
    schemaVersion: 2,
    payload: payload,
    updatedAt: DateTime.utc(2026, 7, 16),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('指令注入实体同时被类型解析器和支持集合识别', () {
    expect(
      CloudSyncEntityType.parse('instruction-injection').wireName,
      'instruction-injection',
    );
    expect(isSupportedCloudSyncEntityType('instruction-injection'), isTrue);
  });

  test('所有同步实体枚举都属于支持集合', () {
    for (final entityType in CloudSyncEntityType.values) {
      expect(
        isSupportedCloudSyncEntityType(entityType.wireName),
        isTrue,
        reason: entityType.wireName,
      );
    }
  });

  test('用户资料持久写入先声明唯一资料实体，失败时不改变本地数据', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final user = UserProvider(syncWriteExecutor: writes);
    await user.ready;

    await user.setName('Alice');

    expect(writes.batches.single, const <SyncEntityKey>[
      SyncEntityKey(entityType: 'user-preference', entityId: 'profile:default'),
    ]);
    expect(user.name, 'Alice');

    writes.rejectWrites = true;
    await expectLater(user.setName('Bob'), throwsStateError);
    expect(user.name, 'Alice');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_name'), 'Alice');
  });

  test('远端配置批次只通知一次且不创建本地 intent', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);
    await fixture.user.setAvatarUrl('https://example.com/avatar.png');
    writes.batches.clear();
    var notifications = 0;
    fixture.user.addListener(() => notifications++);

    await fixture.adapter.runRemoteBatch(() async {
      await fixture.adapter.applyRemoteUpsert(
        _profileEntity(<String, Object?>{'name': 'Cloud A'}),
      );
      await fixture.adapter.applyRemoteUpsert(
        _profileEntity(<String, Object?>{'name': 'Cloud B'}),
      );
    });

    expect(notifications, 1);
    expect(fixture.user.name, 'Cloud B');
    expect(fixture.user.avatarType, isNull);
    expect(fixture.user.avatarValue, isNull);
    expect(writes.batches, isEmpty);
  });

  test('远端资料缺少头像时保留本地文件头像并拒绝残缺头像字段', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);
    await fixture.user.syncApplyProfile(
      name: 'Local',
      replaceAvatar: true,
      avatarType: 'file',
      avatarValue: r'C:\private\avatar.png',
    );

    await fixture.adapter.applyRemoteUpsert(
      _profileEntity(<String, Object?>{'name': 'Cloud'}),
    );

    expect(fixture.user.avatarType, 'file');
    expect(fixture.user.avatarValue, r'C:\private\avatar.png');
    await expectLater(
      fixture.adapter.applyRemoteUpsert(
        _profileEntity(<String, Object?>{
          'name': 'Invalid',
          'avatarType': 'emoji',
        }),
      ),
      throwsFormatException,
    );
    expect(fixture.user.name, 'Cloud');
  });

  test('快捷语重排声明全部受影响位置，无效边界不创建写入', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final phrases = QuickPhraseProvider(syncWriteExecutor: writes);
    for (final id in const <String>['a', 'b', 'c']) {
      await phrases.add(QuickPhrase(id: id, title: id, content: id));
    }
    writes.batches.clear();

    await phrases.reorder(oldIndex: 0, newIndex: 2);

    expect(writes.batches.single, <SyncEntityKey>[
      ConfigSyncKeys.quickPhrase('a'),
      ConfigSyncKeys.quickPhrase('b'),
      ConfigSyncKeys.quickPhrase('c'),
    ]);
    expect(phrases.phrases.map((phrase) => phrase.id), <String>['b', 'c', 'a']);

    writes.batches.clear();
    await phrases.reorder(oldIndex: 0, newIndex: 9);
    expect(writes.batches, isEmpty);
    expect(phrases.phrases.map((phrase) => phrase.id), <String>['b', 'c', 'a']);
  });

  test('删除当前助手时主实体、位置变化和选择偏好处于同一批次', () async {
    final assistants = <Assistant>[
      Assistant(id: 'a', name: 'A'),
      Assistant(id: 'b', name: 'B'),
      Assistant(id: 'c', name: 'C'),
    ];
    SharedPreferences.setMockInitialValues(<String, Object>{
      'assistants_v1': Assistant.encodeList(assistants),
      'current_assistant_id_v1': 'a',
    });
    final writes = _RecordingSyncWriteExecutor();
    final provider = AssistantProvider(syncWriteExecutor: writes);
    await provider.ready;

    expect(await provider.deleteAssistant('a'), isTrue);

    expect(writes.batches.single, <SyncEntityKey>[
      ConfigSyncKeys.assistant('a'),
      ConfigSyncKeys.assistant('b'),
      ConfigSyncKeys.assistant('c'),
      ConfigSyncKeys.assistantSelection,
    ]);
    expect(provider.currentAssistantId, 'b');
  });

  test('远端供应商删除与 MCP 超时应用不反向创建本地 intent', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final settings = SettingsProvider(syncWriteExecutor: writes);
    final mcp = McpProvider(syncWriteExecutor: writes);
    addTearDown(mcp.dispose);
    await Future.wait<void>(<Future<void>>[settings.ready, mcp.ready]);
    await settings.setProviderConfig(
      'custom',
      ProviderConfig.defaultsFor('custom'),
    );
    await mcp.updateRequestTimeout(const Duration(seconds: 45));
    expect(writes.batches, isNotEmpty);
    writes.batches.clear();

    await settings.syncDeleteProviderConfig('custom');
    await mcp.syncUpdateRequestTimeout(const Duration(seconds: 60));

    expect(settings.providerConfigs.containsKey('custom'), isFalse);
    expect(mcp.requestTimeout, const Duration(seconds: 60));
    expect(writes.batches, isEmpty);
  });

  test('复合搜索设置只创建一个完整外层批次，内层 setter 复用声明', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final current = SettingsProvider(syncWriteExecutor: writes);
    final target = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await Future.wait<void>(<Future<void>>[current.ready, target.ready]);
    await target.setSearchEnabled(true);
    await target.setSearchAutoTestOnLaunch(true);
    writes.batches.clear();

    await current.updateSettings(target);

    expect(writes.batches, hasLength(1));
    expect(writes.batches.single, contains(ConfigSyncKeys.searchState));
    expect(current.searchEnabled, isTrue);
    expect(current.searchAutoTestOnLaunch, isTrue);
  });
}
