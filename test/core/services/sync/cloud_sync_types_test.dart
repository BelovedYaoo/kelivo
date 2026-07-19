import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/quick_phrase.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/cloud_sync_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_conflict_presentation.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/config_sync_adapter.dart';
import 'package:Kelivo/core/services/sync/config_sync_keys.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/features/settings/pages/cloud_sync_page.dart'
    show cloudSyncStatusText;
import 'package:Kelivo/l10n/app_localizations.dart';

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
    AssistantProvider assistants,
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
  return (
    adapter: adapter,
    assistants: assistants,
    mcp: mcp,
    settings: settings,
    user: user,
  );
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

RemoteSyncEntity _providerGroupingEntity(Map<String, Object?> payload) {
  return RemoteSyncEntity(
    entityType: ConfigSyncKeys.preferenceType,
    entityId: ConfigSyncKeys.providerGrouping.entityId,
    revision: 1,
    schemaVersion: 2,
    payload: payload,
    updatedAt: DateTime.utc(2026, 7, 16),
  );
}

RemoteSyncEntity _providerEntity(String entityId, {required int position}) {
  final payload =
      Map<String, Object?>.from(ProviderConfig.defaultsFor(entityId).toJson())
        ..remove('id')
        ..['_position'] = position;
  return RemoteSyncEntity(
    entityType: ConfigSyncKeys.providerType,
    entityId: entityId,
    revision: 1,
    schemaVersion: 2,
    payload: payload,
    updatedAt: DateTime.utc(2026, 7, 16),
  );
}

RemoteSyncEntity _assistantEntity(
  String entityId,
  Map<String, Object?> payload,
) {
  return RemoteSyncEntity(
    entityType: ConfigSyncKeys.assistantType,
    entityId: entityId,
    revision: 1,
    schemaVersion: 2,
    payload: <String, Object?>{'_position': 0, ...payload},
    updatedAt: DateTime.utc(2026, 7, 16),
  );
}

CloudSyncConflictField _conflictField({
  required String path,
  bool currentExists = true,
  Object? currentValue,
  bool desiredExists = true,
  Object? desiredValue,
}) {
  return CloudSyncConflictField(
    path: path,
    current: CloudSyncConflictFieldState(
      exists: currentExists,
      value: currentValue,
    ),
    desired: CloudSyncConflictFieldState(
      exists: desiredExists,
      value: desiredValue,
    ),
  );
}

CloudSyncConflict _conflict({
  CloudSyncEntityType entityType = CloudSyncEntityType.assistant,
  required List<CloudSyncConflictField> fields,
}) {
  return CloudSyncConflict(
    conflictId: 'internal-conflict-id',
    mutationId: 'internal-mutation-id',
    entityType: entityType,
    entityId: 'internal-entity-id',
    baseRevision: 1,
    fields: fields,
    state: CloudSyncConflictState.open,
    createdAt: DateTime.utc(2026, 7, 16),
    resolvedAt: null,
  );
}

Object _valueDescriptorTree(CloudSyncConflictValueDescriptor descriptor) {
  return switch (descriptor) {
    CloudSyncAbsentValueDescriptor() => 'absent',
    CloudSyncNullValueDescriptor() => 'null',
    CloudSyncHiddenValueDescriptor(:final state) => <String, Object>{
      'kind': 'hidden',
      'state': state.name,
    },
    CloudSyncReferenceValueDescriptor() => 'reference',
    CloudSyncItemCountValueDescriptor(:final itemCount) => <String, Object>{
      'kind': 'itemCount',
      'value': itemCount,
    },
    CloudSyncBooleanValueDescriptor(:final value) => <String, Object>{
      'kind': 'boolean',
      'value': value,
    },
    CloudSyncNumberValueDescriptor(:final value) => <String, Object>{
      'kind': 'number',
      'value': value,
    },
    CloudSyncTextValueDescriptor(:final value) => <String, Object>{
      'kind': 'text',
      'value': value,
    },
  };
}

Object _presentationDescriptorTree(
  CloudSyncConflictPresentationDescriptor descriptor,
) {
  return <String, Object>{
    'entity': descriptor.entityCategory.name,
    'fields': descriptor.fields
        .map(
          (field) => <String, Object>{
            'category': field.category.name,
            'current': _valueDescriptorTree(field.current),
            'desired': _valueDescriptorTree(field.desired),
          },
        )
        .toList(growable: false),
  };
}

bool _containsRecursively(Object? value, Object? forbidden) {
  if (value == forbidden) return true;
  if (value is Iterable<Object?>) {
    return value.any((item) => _containsRecursively(item, forbidden));
  }
  if (value is Map<Object?, Object?>) {
    return value.entries.any(
      (entry) =>
          _containsRecursively(entry.key, forbidden) ||
          _containsRecursively(entry.value, forbidden),
    );
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('官方云同步服务只使用自定义域名', () {
    expect(defaultCloudSyncBaseUrl, 'https://kelivo.bemylover.top');
  });

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

  test('助手本地媒体路径导出为显式空值以满足同步契约', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'assistants_v1': Assistant.encodeList(const <Assistant>[
        Assistant(
          id: 'assistant-local-media',
          name: '本地媒体助手',
          avatar: r'C:\private\avatar.png',
          background: r'C:\private\background.png',
        ),
      ]),
    });
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);

    final entities = await fixture.adapter.exportLocalEntities();
    final assistant = entities.singleWhere(
      (entity) =>
          entity.key == ConfigSyncKeys.assistant('assistant-local-media'),
    );

    expect(assistant.payload, containsPair('avatar', null));
    expect(assistant.payload, containsPair('background', null));
  });

  test('远端空媒体保留本地助手文件但清除可移植地址', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'assistants_v1': Assistant.encodeList(const <Assistant>[
        Assistant(
          id: 'assistant-local-media',
          name: '本地媒体助手',
          avatar: r'C:\private\avatar.png',
          background: r'C:\private\background.png',
        ),
        Assistant(
          id: 'assistant-portable-media',
          name: '可移植媒体助手',
          avatar: 'https://example.com/avatar.png',
          background: 'https://example.com/background.png',
        ),
      ]),
    });
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);

    for (final entityId in const <String>[
      'assistant-local-media',
      'assistant-portable-media',
    ]) {
      await fixture.adapter.applyRemoteUpsert(
        _assistantEntity(entityId, const <String, Object?>{
          'name': '云端助手',
          'avatar': null,
          'background': null,
        }),
      );
    }

    final local = fixture.assistants.getById('assistant-local-media');
    expect(local?.avatar, 'C:/private/avatar.png');
    expect(local?.background, 'C:/private/background.png');
    final portable = fixture.assistants.getById('assistant-portable-media');
    expect(portable?.avatar, isNull);
    expect(portable?.background, isNull);
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

  test('供应商实体变更始终声明稳定分组键且导出完整顺序', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);
    writes.batches.clear();

    await fixture.settings.setProviderConfig(
      'custom-a',
      ProviderConfig.defaultsFor('custom-a'),
    );
    await fixture.settings.setProviderConfig(
      'custom-b',
      ProviderConfig.defaultsFor('custom-b'),
    );
    await fixture.settings.setProvidersOrder(<String>[
      'custom-b',
      'custom-a',
      ...fixture.settings.providersOrder,
    ]);

    expect(
      writes.batches,
      everyElement(contains(ConfigSyncKeys.providerGrouping)),
    );
    expect(
      writes.batches.first,
      containsAll(<SyncEntityKey>[
        ConfigSyncKeys.providerGrouping,
        ConfigSyncKeys.provider('custom-a'),
      ]),
    );
    final grouping = await fixture.adapter.exportLocalEntity(
      ConfigSyncKeys.providerGrouping,
    );
    expect(grouping, isNotNull);
    expect(grouping!.payload['order'], fixture.settings.providersOrder);
  });

  test('远端供应商完整顺序应用不反向创建本地 intent', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);
    await fixture.settings.setProviderConfig(
      'custom-a',
      ProviderConfig.defaultsFor('custom-a'),
    );
    final reversedOrder = fixture.settings.providersOrder.reversed.toList();
    writes.batches.clear();

    await fixture.adapter.applyRemoteUpsert(
      _providerGroupingEntity(<String, Object?>{
        'order': reversedOrder,
        'groups': const <Object?>[],
        'assignments': const <String, Object?>{},
        'ungroupedPosition': 0,
      }),
    );

    expect(fixture.settings.providersOrder, reversedOrder);
    expect(writes.batches, isEmpty);
  });

  test('旧版供应商分组缺少完整顺序时保留当前顺序并应用可推导分组', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);
    await fixture.settings.setProviderConfig(
      'custom-a',
      ProviderConfig.defaultsFor('custom-a'),
    );
    final originalOrder = List<String>.of(fixture.settings.providersOrder);
    writes.batches.clear();

    await fixture.adapter.applyRemoteUpsert(
      _providerGroupingEntity(<String, Object?>{
        'groups': const <Object?>[
          <String, Object?>{
            'id': 'legacy-group',
            'name': '旧版分组',
            'createdAt': 1,
          },
        ],
        'assignments': const <String, Object?>{'custom-a': 'legacy-group'},
        'ungroupedPosition': 0,
      }),
    );

    expect(fixture.settings.providersOrder, originalOrder);
    expect(fixture.settings.groupIdForProvider('custom-a'), 'legacy-group');
    expect(writes.batches, isEmpty);
  });

  test('远端批次先到完整顺序时仍在供应商实体之后提交', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);
    final expectedOrder = <String>[
      'remote-a',
      'remote-b',
      ...fixture.settings.providersOrder,
    ];
    writes.batches.clear();

    await fixture.adapter.runRemoteBatch(() async {
      await fixture.adapter.applyRemoteUpsert(
        _providerGroupingEntity(<String, Object?>{
          'order': expectedOrder,
          'groups': const <Object?>[],
          'assignments': const <String, Object?>{},
          'ungroupedPosition': 0,
        }),
      );
      await fixture.adapter.applyRemoteUpsert(
        _providerEntity('remote-b', position: 1),
      );
      await fixture.adapter.applyRemoteUpsert(
        _providerEntity('remote-a', position: 0),
      );
    });

    expect(fixture.settings.providersOrder, expectedOrder);
    expect(writes.batches, isEmpty);
  });

  test('完整远端事务跨分页暂存分组直至相关供应商到齐', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);
    final expectedOrder = <String>[
      'remote-a',
      ...fixture.settings.providersOrder,
    ];
    final committedKeys = <SyncEntityKey>[];

    await fixture.adapter.runRemoteTransaction(
      () async {
        await fixture.adapter.runRemoteBatch(() async {
          await fixture.adapter.applyRemoteUpsert(
            _providerGroupingEntity(<String, Object?>{
              'order': expectedOrder,
              'groups': const <Object?>[
                <String, Object?>{
                  'id': 'remote-group',
                  'name': '远端分组',
                  'createdAt': 1,
                },
              ],
              'assignments': const <String, Object?>{
                'remote-a': 'remote-group',
              },
              'ungroupedPosition': 0,
            }),
          );
        });
        expect(fixture.settings.providerGroups, isEmpty);

        await fixture.adapter.runRemoteBatch(() async {
          await fixture.adapter.applyRemoteUpsert(
            _providerEntity('remote-a', position: 0),
          );
        });
      },
      commit: (keys, write) async {
        committedKeys.addAll(keys);
        await write();
      },
    );

    expect(committedKeys, <SyncEntityKey>[ConfigSyncKeys.providerGrouping]);
    expect(fixture.settings.providersOrder, expectedOrder);
    expect(fixture.settings.groupIdForProvider('remote-a'), 'remote-group');
  });

  test('完整远端事务失败会丢弃跨分页暂存分组', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);
    final originalOrder = List<String>.of(fixture.settings.providersOrder);
    var commitCount = 0;

    await expectLater(
      fixture.adapter.runRemoteTransaction<void>(
        () async {
          await fixture.adapter.runRemoteBatch(() async {
            await fixture.adapter.applyRemoteUpsert(
              _providerGroupingEntity(<String, Object?>{
                'order': originalOrder.reversed.toList(),
                'groups': const <Object?>[],
                'assignments': const <String, Object?>{},
                'ungroupedPosition': 0,
              }),
            );
          });
          throw StateError('模拟完整远端事务失败');
        },
        commit: (keys, write) async {
          commitCount++;
          await write();
        },
      ),
      throwsStateError,
    );
    await fixture.adapter.runRemoteTransaction<void>(
      () async {},
      commit: (keys, write) async {
        commitCount++;
        await write();
      },
    );

    expect(commitCount, 0);
    expect(fixture.settings.providersOrder, originalOrder);
  });

  test('远端供应商批次失败会丢弃尚未提交的完整顺序', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final writes = _RecordingSyncWriteExecutor();
    final fixture = await _createConfigFixture(writes);
    addTearDown(fixture.mcp.dispose);
    final originalOrder = List<String>.of(fixture.settings.providersOrder);
    writes.batches.clear();

    await expectLater(
      fixture.adapter.runRemoteBatch<void>(() async {
        await fixture.adapter.applyRemoteUpsert(
          _providerGroupingEntity(<String, Object?>{
            'order': originalOrder.reversed.toList(),
            'groups': const <Object?>[],
            'assignments': const <String, Object?>{},
            'ungroupedPosition': 0,
          }),
        );
        throw StateError('模拟远端批次失败');
      }),
      throwsStateError,
    );
    await fixture.adapter.runRemoteBatch<void>(() async {});

    expect(fixture.settings.providersOrder, originalOrder);
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

  group('云同步冲突展示描述', () {
    test('将冲突转换为实体、字段和值的强类型描述', () {
      final descriptor = describeCloudSyncConflict(
        _conflict(
          fields: <CloudSyncConflictField>[
            _conflictField(
              path: '/displayName',
              currentValue: '旧助手',
              desiredValue: '新助手',
            ),
          ],
        ),
      );

      expect(
        descriptor.entityCategory,
        CloudSyncConflictEntityCategory.assistant,
      );
      expect(descriptor.fields, hasLength(1));
      expect(
        descriptor.fields.single.category,
        CloudSyncConflictFieldCategory.name,
      );
      expect(
        descriptor.fields.single.current,
        isA<CloudSyncTextValueDescriptor>().having(
          (value) => value.value,
          'value',
          '旧助手',
        ),
      );
      expect(
        descriptor.fields.single.desired,
        isA<CloudSyncTextValueDescriptor>().having(
          (value) => value.value,
          'value',
          '新助手',
        ),
      );
    });

    test('全部实体枚举都有稳定的展示类别', () {
      const expected = <CloudSyncEntityType, CloudSyncConflictEntityCategory>{
        CloudSyncEntityType.conversation:
            CloudSyncConflictEntityCategory.conversation,
        CloudSyncEntityType.turn: CloudSyncConflictEntityCategory.turn,
        CloudSyncEntityType.message: CloudSyncConflictEntityCategory.message,
        CloudSyncEntityType.messageSelection:
            CloudSyncConflictEntityCategory.messageSelection,
        CloudSyncEntityType.toolEvent:
            CloudSyncConflictEntityCategory.toolEvent,
        CloudSyncEntityType.thoughtSignature:
            CloudSyncConflictEntityCategory.thoughtSignature,
        CloudSyncEntityType.provider: CloudSyncConflictEntityCategory.provider,
        CloudSyncEntityType.assistant:
            CloudSyncConflictEntityCategory.assistant,
        CloudSyncEntityType.memory: CloudSyncConflictEntityCategory.memory,
        CloudSyncEntityType.worldBook:
            CloudSyncConflictEntityCategory.worldBook,
        CloudSyncEntityType.quickPhrase:
            CloudSyncConflictEntityCategory.quickPhrase,
        CloudSyncEntityType.searchService:
            CloudSyncConflictEntityCategory.searchService,
        CloudSyncEntityType.networkTts:
            CloudSyncConflictEntityCategory.networkTts,
        CloudSyncEntityType.mcpServer:
            CloudSyncConflictEntityCategory.mcpServer,
        CloudSyncEntityType.instructionInjection:
            CloudSyncConflictEntityCategory.instructionInjection,
        CloudSyncEntityType.userPreference:
            CloudSyncConflictEntityCategory.userPreference,
      };

      for (final entry in expected.entries) {
        final descriptor = describeCloudSyncConflict(
          _conflict(
            entityType: entry.key,
            fields: <CloudSyncConflictField>[
              _conflictField(path: '/title', currentValue: 'a'),
            ],
          ),
        );
        expect(descriptor.entityCategory, entry.value);
      }
      expect(expected, hasLength(CloudSyncEntityType.values.length));
    });

    test('所有字段展示类别均由顶层 JSON Pointer 得出', () {
      const expected = <String, CloudSyncConflictFieldCategory>{
        '/title': CloudSyncConflictFieldCategory.title,
        '/content': CloudSyncConflictFieldCategory.content,
        '/summary': CloudSyncConflictFieldCategory.summary,
        '/displayName': CloudSyncConflictFieldCategory.name,
        '/status': CloudSyncConflictFieldCategory.status,
        '/updatedAt': CloudSyncConflictFieldCategory.time,
        '/settings': CloudSyncConflictFieldCategory.settings,
        '/apiKey': CloudSyncConflictFieldCategory.security,
        '/providerId': CloudSyncConflictFieldCategory.reference,
        '/attachments': CloudSyncConflictFieldCategory.attachments,
        '/selection': CloudSyncConflictFieldCategory.selection,
        '/customColor': CloudSyncConflictFieldCategory.other,
      };

      for (final entry in expected.entries) {
        final descriptor = describeCloudSyncConflictField(
          _conflictField(path: entry.key, currentValue: 'value'),
        );
        expect(descriptor.category, entry.value, reason: entry.key);
      }
    });

    test('大小写与 camelCase 敏感关键词只生成隐藏状态且不保留原值', () {
      const paths = <String>[
        '/apiKey',
        '/ACCESS_TOKEN',
        '/clientSecret',
        '/userPassword',
        '/Authorization',
        '/customHeaders',
        '/accessCredential',
        '/thoughtSignature',
      ];

      for (final path in paths) {
        final secret = 'secret-value-for-$path';
        final descriptor = describeCloudSyncConflictField(
          _conflictField(
            path: path,
            currentValue: secret,
            desiredExists: false,
          ),
        );
        final current = descriptor.current;
        final desired = descriptor.desired;

        expect(descriptor.category, CloudSyncConflictFieldCategory.security);
        expect(
          current,
          isA<CloudSyncHiddenValueDescriptor>().having(
            (value) => value.state,
            'state',
            CloudSyncHiddenValueState.set,
          ),
        );
        expect(
          desired,
          isA<CloudSyncHiddenValueDescriptor>().having(
            (value) => value.state,
            'state',
            CloudSyncHiddenValueState.missing,
          ),
        );
        final tree = <String, Object>{
          'current': _valueDescriptorTree(current),
          'desired': _valueDescriptorTree(desired),
        };
        expect(_containsRecursively(tree, secret), isFalse, reason: path);
        expect(descriptor.toString(), isNot(contains(secret)), reason: path);
      }
    });

    test('引用字段不暴露 ID，引用集合仅给出项目数量', () {
      const currentId = 'provider-sensitive-id';
      const desiredIds = <Object?>['first-sensitive-id', 'second-sensitive-id'];
      final scalar = describeCloudSyncConflictField(
        _conflictField(
          path: '/providerId',
          currentValue: currentId,
          desiredValue: 'next-sensitive-id',
        ),
      );
      final collection = describeCloudSyncConflictField(
        _conflictField(
          path: '/providerIds',
          currentValue: desiredIds,
          desiredValue: const <String, Object?>{
            'primary': 'third-sensitive-id',
          },
        ),
      );

      expect(scalar.current, isA<CloudSyncReferenceValueDescriptor>());
      expect(scalar.desired, isA<CloudSyncReferenceValueDescriptor>());
      expect(
        collection.current,
        isA<CloudSyncItemCountValueDescriptor>().having(
          (value) => value.itemCount,
          'itemCount',
          2,
        ),
      );
      expect(
        collection.desired,
        isA<CloudSyncItemCountValueDescriptor>().having(
          (value) => value.itemCount,
          'itemCount',
          1,
        ),
      );
      final tree = <Object>[
        _valueDescriptorTree(scalar.current),
        _valueDescriptorTree(scalar.desired),
        _valueDescriptorTree(collection.current),
        _valueDescriptorTree(collection.desired),
      ];
      for (final id in <String>[
        currentId,
        'next-sensitive-id',
        'first-sensitive-id',
        'second-sensitive-id',
        'third-sensitive-id',
      ]) {
        expect(_containsRecursively(tree, id), isFalse);
      }
    });

    test('对象与数组只给数量，布尔、缺失、null、数字分别描述', () {
      final descriptors = <CloudSyncConflictFieldDescriptor>[
        describeCloudSyncConflictField(
          _conflictField(
            path: '/settings',
            currentValue: const <String, Object?>{'a': 1, 'b': 2},
            desiredValue: const <Object?>['a', 'b', 'c'],
          ),
        ),
        describeCloudSyncConflictField(
          _conflictField(
            path: '/enabled',
            currentValue: true,
            desiredExists: false,
          ),
        ),
        describeCloudSyncConflictField(
          _conflictField(
            path: '/temperature',
            currentValue: null,
            desiredValue: 0.7,
          ),
        ),
      ];

      expect(
        descriptors[0].current,
        isA<CloudSyncItemCountValueDescriptor>().having(
          (value) => value.itemCount,
          'itemCount',
          2,
        ),
      );
      expect(
        descriptors[0].desired,
        isA<CloudSyncItemCountValueDescriptor>().having(
          (value) => value.itemCount,
          'itemCount',
          3,
        ),
      );
      expect(descriptors[1].current, isA<CloudSyncBooleanValueDescriptor>());
      expect(descriptors[1].desired, isA<CloudSyncAbsentValueDescriptor>());
      expect(descriptors[2].current, isA<CloudSyncNullValueDescriptor>());
      expect(
        descriptors[2].desired,
        isA<CloudSyncNumberValueDescriptor>().having(
          (value) => value.value,
          'value',
          0.7,
        ),
      );
    });

    test('嵌套和无法安全解释的路径归入其他且不回显路径或内部标识', () {
      const originalPaths = <String>['/settings/apiKey', '/bad~1path'];
      final descriptor = describeCloudSyncConflict(
        _conflict(
          fields: <CloudSyncConflictField>[
            for (final path in originalPaths)
              _conflictField(
                path: path,
                currentValue: 'nested-sensitive-value',
              ),
          ],
        ),
      );
      final tree = _presentationDescriptorTree(descriptor);

      for (final field in descriptor.fields) {
        expect(field.category, CloudSyncConflictFieldCategory.other);
      }
      for (final forbidden in <String>[
        ...originalPaths,
        'internal-conflict-id',
        'internal-mutation-id',
        'internal-entity-id',
        'nested-sensitive-value',
      ]) {
        expect(_containsRecursively(tree, forbidden), isFalse);
        expect(descriptor.toString(), isNot(contains(forbidden)));
      }
    });
  });

  group('云同步状态文案', () {
    test('待同步和待确认使用不同的用户文案', () {
      final l10n = lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      );

      expect(
        cloudSyncStatusText(l10n, CloudSyncProviderStatus.pendingSync),
        '仍有数据未同步',
      );
      expect(
        cloudSyncStatusText(l10n, CloudSyncProviderStatus.needsAttention),
        '有待确认项',
      );
      expect(
        cloudSyncStatusText(l10n, CloudSyncProviderStatus.syncBlocked),
        '部分数据同步失败',
      );
    });
  });

  group('云账号首次 hydration 门禁', () {
    test('本地工作区无需云端 hydration 即可初始化默认助手', () {
      expect(
        CloudSyncInitialHydrationState.initialForWorkspace(
          isLocalWorkspace: true,
        ).allowsAssistantDefaults,
        isTrue,
      );
    });

    test('云账号工作区在 hydration 成功前始终阻止默认助手初始化', () {
      expect(
        CloudSyncInitialHydrationState.initialForWorkspace(
          isLocalWorkspace: false,
        ).allowsAssistantDefaults,
        isFalse,
      );
    });

    test('云账号工作区仅在 hydration 完成后允许初始化默认助手', () {
      expect(
        CloudSyncInitialHydrationState.completed.allowsAssistantDefaults,
        isTrue,
      );
    });

    testWidgets('两个空工作区生成相同的保留默认助手身份', (tester) async {
      Future<Set<String>> createDefaultIds() async {
        SharedPreferences.setMockInitialValues(const <String, Object>{});
        final provider = AssistantProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        );
        await provider.ready;
        late BuildContext localizedContext;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) {
                localizedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await provider.ensureDefaults(localizedContext);
        final ids = provider.assistants
            .map((assistant) => assistant.id)
            .toSet();
        provider.dispose();
        return ids;
      }

      final first = await createDefaultIds();
      final second = await createDefaultIds();

      const reservedIds = <String>{
        'c4f7b8e1-8f7b-4d2a-9c31-0e7d6a5b4001',
        'c4f7b8e1-8f7b-4d2a-9c31-0e7d6a5b4002',
      };
      expect(first, reservedIds);
      expect(second, reservedIds);
    });
  });
}
