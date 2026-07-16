import 'package:flutter/foundation.dart';
import '../models/quick_phrase.dart';
import '../services/quick_phrase_store.dart';
import '../services/sync/config_sync_keys.dart';
import '../services/sync/sync_write_executor.dart';
import '../utils/batched_change_notifier.dart';
export '../services/sync/sync_write_executor.dart'
    show UntrackedSyncWriteExecutor;

class QuickPhraseProvider with ChangeNotifier, BatchedChangeNotifier {
  List<QuickPhrase> _phrases = [];
  bool _initialized = false;
  final SyncWriteExecutor _syncWrites;

  QuickPhraseProvider({required SyncWriteExecutor syncWriteExecutor})
    : _syncWrites = syncWriteExecutor;

  List<QuickPhrase> get phrases => List.unmodifiable(_phrases);

  List<QuickPhrase> get globalPhrases =>
      _phrases.where((p) => p.isGlobal).toList();

  List<QuickPhrase> getForAssistant(String assistantId) => _phrases
      .where((p) => !p.isGlobal && p.assistantId == assistantId)
      .toList();

  Future<void> initialize() async {
    if (_initialized) return;
    await loadAll();
    _initialized = true;
  }

  Future<void> loadAll() async {
    try {
      _phrases = await QuickPhraseStore.getAll();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load quick phrases: $e');
      _phrases = [];
      notifyListeners();
    }
  }

  Future<void> add(QuickPhrase phrase) async {
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.quickPhrase(phrase.id),
      write: () async {
        await QuickPhraseStore.add(phrase);
        await loadAll();
      },
    );
  }

  Future<void> update(QuickPhrase phrase) async {
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.quickPhrase(phrase.id),
      write: () async {
        await QuickPhraseStore.update(phrase);
        await loadAll();
      },
    );
  }

  Future<void> delete(String id) async {
    await initialize();
    final index = _phrases.indexWhere((phrase) => phrase.id == id);
    if (index < 0) return;
    await _syncWrites.runLocalBatch(
      keys: _phrases
          .skip(index)
          .map((phrase) => ConfigSyncKeys.quickPhrase(phrase.id)),
      write: () async {
        await QuickPhraseStore.delete(id);
        await loadAll();
      },
    );
  }

  Future<void> clear() async {
    await initialize();
    if (_phrases.isEmpty) return;
    await _syncWrites.runLocalBatch(
      keys: _phrases.map((phrase) => ConfigSyncKeys.quickPhrase(phrase.id)),
      write: () async {
        await QuickPhraseStore.clear();
        _phrases = [];
        notifyListeners();
      },
    );
  }

  Future<void> syncUpsert(QuickPhrase phrase, {required int position}) async {
    await initialize();
    final phrases = List<QuickPhrase>.from(_phrases)
      ..removeWhere((e) => e.id == phrase.id);
    phrases.insert(position.clamp(0, phrases.length), phrase);
    _phrases = phrases;
    await QuickPhraseStore.save(_phrases);
    notifyListeners();
  }

  Future<void> syncDelete(String id) async {
    await initialize();
    final phrases = List<QuickPhrase>.from(_phrases);
    final before = phrases.length;
    phrases.removeWhere((e) => e.id == id);
    if (phrases.length == before) return;
    _phrases = phrases;
    await QuickPhraseStore.save(_phrases);
    notifyListeners();
  }

  void _reorderInMemory({
    required int oldIndex,
    required int newIndex,
    String? assistantId,
  }) {
    final bool isGlobal = assistantId == null;

    // Determine indices in the subset (global or specific assistant)
    final List<int> subsetIndices = [];
    for (int i = 0; i < _phrases.length; i++) {
      final p = _phrases[i];
      final matches = isGlobal
          ? p.isGlobal
          : (!p.isGlobal && p.assistantId == assistantId);
      if (matches) subsetIndices.add(i);
    }

    if (subsetIndices.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= subsetIndices.length) return;
    if (newIndex < 0 || newIndex >= subsetIndices.length) return;

    // Extract the subset in current order
    final List<QuickPhrase> subset = subsetIndices
        .map((i) => _phrases[i])
        .toList(growable: true);

    final item = subset.removeAt(oldIndex);
    subset.insert(newIndex, item);

    // Merge reordered subset back into original list
    final List<QuickPhrase> merged = [];
    int take = 0;
    for (int i = 0; i < _phrases.length; i++) {
      final p = _phrases[i];
      final matches = isGlobal
          ? p.isGlobal
          : (!p.isGlobal && p.assistantId == assistantId);
      if (matches) {
        merged.add(subset[take++]);
      } else {
        merged.add(p);
      }
    }
    _phrases = merged;
  }

  Future<void> reorder({
    required int oldIndex,
    required int newIndex,
    String? assistantId,
  }) async {
    await initialize();
    final subset = assistantId == null
        ? globalPhrases
        : getForAssistant(assistantId);
    if (oldIndex < 0 || oldIndex >= subset.length) return;
    if (newIndex < 0 || newIndex >= subset.length) return;
    if (oldIndex == newIndex) return;
    final start = oldIndex < newIndex ? oldIndex : newIndex;
    final end = oldIndex > newIndex ? oldIndex : newIndex;
    await _syncWrites.runLocalBatch(
      keys: subset
          .sublist(start, end + 1)
          .map((phrase) => ConfigSyncKeys.quickPhrase(phrase.id)),
      write: () async {
        _reorderInMemory(
          oldIndex: oldIndex,
          newIndex: newIndex,
          assistantId: assistantId,
        );
        notifyListeners();
        await QuickPhraseStore.save(_phrases);
      },
    );
  }

  // Backward/alternate API name for clarity
  Future<void> reorderPhrases({
    required int oldIndex,
    required int newIndex,
    String? assistantId,
  }) async {
    await reorder(
      oldIndex: oldIndex,
      newIndex: newIndex,
      assistantId: assistantId,
    );
  }
}
