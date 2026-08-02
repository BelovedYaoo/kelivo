import 'package:flutter/foundation.dart';
import '../models/assistant_memory.dart';
import '../services/memory_store.dart';
import '../services/sync/config_sync_keys.dart';
import '../services/sync/sync_write_executor.dart';
import '../utils/batched_change_notifier.dart';

class MemoryProvider extends ChangeNotifier with BatchedChangeNotifier {
  List<AssistantMemory> _memories = <AssistantMemory>[];
  bool _initialized = false;
  final SyncWriteExecutor _syncWrites;

  MemoryProvider({required SyncWriteExecutor syncWriteExecutor})
    : _syncWrites = syncWriteExecutor;

  List<AssistantMemory> get memories => List.unmodifiable(_memories);

  List<AssistantMemory> getForAssistant(String assistantId) =>
      _memories.where((m) => m.assistantId == assistantId).toList();

  Future<void> initialize() async {
    if (_initialized) return;
    if (!usesE2eeConfigVault(_syncWrites)) await loadAll();
    _initialized = true;
  }

  Future<void> loadAll() async {
    try {
      _memories = await MemoryStore.getAll();
      notifyListeners();
    } catch (_) {
      debugPrint('[MemoryProvider] load failed');
      _memories = <AssistantMemory>[];
      notifyListeners();
    }
  }

  Future<AssistantMemory> add({
    required String assistantId,
    required String content,
  }) async {
    final draft = AssistantMemory(
      id: 0,
      assistantId: assistantId,
      content: content,
    );
    return _syncWrites.runLocal(
      key: ConfigSyncKeys.memory(draft.syncId),
      write: () async {
        if (usesE2eeConfigVault(_syncWrites)) {
          final memory = draft.copyWith(id: _nextId());
          _memories = <AssistantMemory>[..._memories, memory];
          notifyListeners();
          return memory;
        }
        final memory = await MemoryStore.add(
          assistantId: assistantId,
          content: content,
          syncId: draft.syncId,
        );
        await loadAll();
        return memory;
      },
    );
  }

  Future<AssistantMemory?> update({
    required int id,
    required String content,
  }) async {
    await initialize();
    final current = _memories.where((memory) => memory.id == id).firstOrNull;
    if (current == null) return null;
    return _syncWrites.runLocal(
      key: ConfigSyncKeys.memory(current.syncId),
      write: () async {
        if (usesE2eeConfigVault(_syncWrites)) {
          final index = _memories.indexWhere((memory) => memory.id == id);
          final memory = _memories[index].copyWith(content: content);
          _memories = List<AssistantMemory>.of(_memories)..[index] = memory;
          notifyListeners();
          return memory;
        }
        final memory = await MemoryStore.update(id: id, content: content);
        await loadAll();
        return memory;
      },
    );
  }

  Future<bool> delete({required int id}) async {
    await initialize();
    final current = _memories.where((memory) => memory.id == id).firstOrNull;
    if (current == null) return false;
    return _syncWrites.runLocal(
      key: ConfigSyncKeys.memory(current.syncId),
      write: () async {
        if (usesE2eeConfigVault(_syncWrites)) {
          _memories = _memories
              .where((memory) => memory.id != id)
              .toList(growable: false);
          notifyListeners();
          return true;
        }
        final deleted = await MemoryStore.delete(id: id);
        await loadAll();
        return deleted;
      },
    );
  }

  Future<void> syncUpsert(AssistantMemory memory) async {
    await initialize();
    if (usesE2eeConfigVault(_syncWrites)) {
      final index = _memories.indexWhere(
        (candidate) => candidate.syncId == memory.syncId,
      );
      final persisted = memory.copyWith(
        id: index < 0 ? _nextId() : _memories[index].id,
      );
      if (index < 0) {
        _memories = <AssistantMemory>[..._memories, persisted];
      } else {
        _memories = List<AssistantMemory>.of(_memories)..[index] = persisted;
      }
      notifyListeners();
      return;
    }
    await MemoryStore.upsertBySyncId(memory);
    await loadAll();
  }

  Future<void> syncDelete(String syncId) async {
    await initialize();
    if (usesE2eeConfigVault(_syncWrites)) {
      final next = _memories
          .where((memory) => memory.syncId != syncId)
          .toList(growable: false);
      if (next.length == _memories.length) return;
      _memories = next;
      notifyListeners();
      return;
    }
    if (await MemoryStore.deleteBySyncId(syncId)) {
      await loadAll();
    }
  }

  int _nextId() {
    var maximum = 0;
    for (final memory in _memories) {
      if (memory.id > maximum) maximum = memory.id;
    }
    return maximum + 1;
  }
}
