import 'package:flutter/foundation.dart';
import '../models/assistant_memory.dart';
import '../services/memory_store.dart';
import '../services/sync/config_sync_keys.dart';
import '../services/sync/sync_write_executor.dart';
import '../utils/batched_change_notifier.dart';
export '../services/sync/sync_write_executor.dart'
    show UntrackedSyncWriteExecutor;

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
    await loadAll();
    _initialized = true;
  }

  Future<void> loadAll() async {
    try {
      _memories = await MemoryStore.getAll();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load memories: $e');
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
        final deleted = await MemoryStore.delete(id: id);
        await loadAll();
        return deleted;
      },
    );
  }

  Future<void> syncUpsert(AssistantMemory memory) async {
    await initialize();
    await MemoryStore.upsertBySyncId(memory);
    await loadAll();
  }

  Future<void> syncDelete(String syncId) async {
    await initialize();
    if (await MemoryStore.deleteBySyncId(syncId)) {
      await loadAll();
    }
  }
}
