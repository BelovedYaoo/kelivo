import 'package:flutter/foundation.dart';

import '../models/instruction_injection.dart';
import '../services/instruction_injection_store.dart';
import '../services/sync/config_sync_keys.dart';
import '../services/sync/sync_codec.dart';
import '../services/sync/sync_write_executor.dart';
import '../utils/batched_change_notifier.dart';

class InstructionInjectionProvider with ChangeNotifier, BatchedChangeNotifier {
  List<InstructionInjection> _items = const <InstructionInjection>[];
  bool _initialized = false;
  Map<String, List<String>> _activeIdsByAssistant =
      const <String, List<String>>{};
  final SyncWriteExecutor _syncWrites;

  InstructionInjectionProvider({required SyncWriteExecutor syncWriteExecutor})
    : _syncWrites = syncWriteExecutor;

  String _normGroup(String g) => g.trim();

  List<InstructionInjection> get items =>
      List<InstructionInjection>.unmodifiable(_items);
  Map<String, List<String>> get activeIdsByAssistant =>
      Map<String, List<String>>.unmodifiable(
        _activeIdsByAssistant.map(
          (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
        ),
      );
  List<String> get activeIds => activeIdsFor(null);

  List<String> activeIdsFor(String? assistantId) {
    final key = InstructionInjectionStore.assistantKey(assistantId);
    if (_activeIdsByAssistant.containsKey(key)) {
      return List<String>.unmodifiable(_activeIdsByAssistant[key]!);
    }
    final fallback =
        _activeIdsByAssistant[InstructionInjectionStore.assistantKey(null)] ??
        const <String>[];
    return List<String>.unmodifiable(fallback);
  }

  bool isActive(String id, {String? assistantId}) =>
      activeIdsFor(assistantId).contains(id);

  List<InstructionInjection> get actives => activesFor(null);

  List<InstructionInjection> activesFor(String? assistantId) {
    final ids = activeIdsFor(assistantId).toSet();
    return _items.where((e) => ids.contains(e.id)).toList(growable: false);
  }

  String? get activeId => activeIdFor(null);
  String? activeIdFor(String? assistantId) {
    final ids = activeIdsFor(assistantId);
    return ids.isEmpty ? null : ids.first;
  }

  InstructionInjection? get active => activeFor(null);
  InstructionInjection? activeFor(String? assistantId) {
    final list = activesFor(assistantId);
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await loadAll();
    _initialized = true;
  }

  Future<void> loadAll() async {
    try {
      _items = await InstructionInjectionStore.getAll();
      _activeIdsByAssistant =
          await InstructionInjectionStore.getActiveIdsByAssistant();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load instruction injections: $e');
      _items = const <InstructionInjection>[];
      _activeIdsByAssistant = const <String, List<String>>{};
      notifyListeners();
    }
  }

  Future<void> add(InstructionInjection item) async {
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.instructionInjection(item.id),
      write: () async {
        await InstructionInjectionStore.add(item);
        await loadAll();
      },
    );
  }

  Future<void> addMany(List<InstructionInjection> items) async {
    if (items.isEmpty) return;
    await _syncWrites.runLocalBatch(
      keys: items.map((item) => ConfigSyncKeys.instructionInjection(item.id)),
      write: () async {
        await InstructionInjectionStore.addMany(items);
        await loadAll();
      },
    );
  }

  Future<void> update(InstructionInjection item) async {
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.instructionInjection(item.id),
      write: () async {
        await InstructionInjectionStore.update(item);
        await loadAll();
      },
    );
  }

  Future<void> delete(String id) async {
    await initialize();
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    await _syncWrites.runLocalBatch(
      keys: <SyncEntityKey>[
        ..._items
            .skip(index)
            .map((item) => ConfigSyncKeys.instructionInjection(item.id)),
        ConfigSyncKeys.instructionActivity,
      ],
      write: () async {
        await InstructionInjectionStore.delete(id);
        await loadAll();
      },
    );
  }

  Future<void> clear() async {
    await initialize();
    await _syncWrites.runLocalBatch(
      keys: <SyncEntityKey>[
        ..._items.map((item) => ConfigSyncKeys.instructionInjection(item.id)),
        ConfigSyncKeys.instructionActivity,
      ],
      write: () async {
        await InstructionInjectionStore.clear();
        _items = const <InstructionInjection>[];
        _activeIdsByAssistant = const <String, List<String>>{};
        notifyListeners();
      },
    );
  }

  Future<void> syncUpsert(
    InstructionInjection item, {
    required int position,
  }) async {
    await initialize();
    final items = List<InstructionInjection>.from(_items)
      ..removeWhere((e) => e.id == item.id);
    items.insert(position.clamp(0, items.length), item);
    _items = List<InstructionInjection>.unmodifiable(items);
    await InstructionInjectionStore.save(_items);
    notifyListeners();
  }

  Future<void> syncDelete(String id) async {
    await initialize();
    if (!_items.any((e) => e.id == id)) return;
    await InstructionInjectionStore.delete(id);
    await loadAll();
  }

  Future<void> syncReplaceActiveIds(Map<String, List<String>> activeIds) async {
    await initialize();
    await InstructionInjectionStore.setActiveIdsMap(activeIds);
    _activeIdsByAssistant = <String, List<String>>{
      for (final entry in activeIds.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    };
    notifyListeners();
  }

  Future<void> reorder({required int oldIndex, required int newIndex}) async {
    if (_items.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (newIndex < 0 || newIndex >= _items.length) return;
    if (oldIndex == newIndex) return;
    final start = oldIndex < newIndex ? oldIndex : newIndex;
    final end = oldIndex > newIndex ? oldIndex : newIndex;
    await _syncWrites.runLocalBatch(
      keys: _items
          .sublist(start, end + 1)
          .map((item) => ConfigSyncKeys.instructionInjection(item.id)),
      write: () async {
        final list = List<InstructionInjection>.from(_items);
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        _items = list;
        notifyListeners();
        await InstructionInjectionStore.save(_items);
      },
    );
  }

  Future<void> reorderWithinGroup({
    required String group,
    required int oldIndex,
    required int newIndex,
  }) async {
    if (_items.isEmpty) return;

    final targetGroup = _normGroup(group);
    final indices = <int>[];
    for (int i = 0; i < _items.length; i++) {
      if (_normGroup(_items[i].group) == targetGroup) indices.add(i);
    }
    if (indices.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= indices.length) return;
    if (newIndex < 0 || newIndex > indices.length) return;

    if (oldIndex == newIndex) return;
    final affectedStart = oldIndex < newIndex ? oldIndex : newIndex;
    final affectedEnd = oldIndex > newIndex ? oldIndex : newIndex;
    final affectedKeys = indices
        .sublist(affectedStart, affectedEnd + 1)
        .map((index) => ConfigSyncKeys.instructionInjection(_items[index].id));

    await _syncWrites.runLocalBatch(
      keys: affectedKeys,
      write: () async {
        final globalOld = indices[oldIndex];
        final list = List<InstructionInjection>.from(_items);
        final moved = list.removeAt(globalOld);

        final after = <int>[];
        for (int i = 0; i < list.length; i++) {
          if (_normGroup(list[i].group) == targetGroup) after.add(i);
        }

        final int insertAt;
        if (newIndex >= after.length) {
          insertAt = after.isEmpty ? list.length : after.last + 1;
        } else {
          insertAt = after[newIndex];
        }
        list.insert(insertAt, moved);

        _items = list;
        notifyListeners();
        await InstructionInjectionStore.save(_items);
      },
    );
  }

  Future<void> setActiveId(String? id, {String? assistantId}) async {
    if (id == null || id.isEmpty) {
      await setActiveIds(const <String>[], assistantId: assistantId);
      return;
    }
    await setActiveIds(<String>[id], assistantId: assistantId);
  }

  Future<void> setActiveIds(List<String> ids, {String? assistantId}) async {
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.instructionActivity,
      write: () async {
        final key = InstructionInjectionStore.assistantKey(assistantId);
        final nextMap = Map<String, List<String>>.from(_activeIdsByAssistant);
        nextMap[key] = ids.toSet().toList(growable: false);
        _activeIdsByAssistant = nextMap;
        notifyListeners();
        await InstructionInjectionStore.setActiveIds(
          ids,
          assistantId: assistantId,
        );
      },
    );
  }

  Future<void> toggleActiveId(String id, {String? assistantId}) async {
    final set = activeIdsFor(assistantId).toSet();
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
    await setActiveIds(set.toList(growable: false), assistantId: assistantId);
  }

  Future<void> setActive(InstructionInjection? item, {String? assistantId}) =>
      setActiveId(item?.id, assistantId: assistantId);
}
