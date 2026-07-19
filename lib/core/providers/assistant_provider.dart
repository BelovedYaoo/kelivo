import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../models/assistant.dart';
import '../models/assistant_regex.dart';
import '../models/preset_message.dart';
import '../services/chat/chat_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/avatar_cache.dart';
import '../../utils/app_directories.dart';
import '../services/sync/config_sync_keys.dart';
import '../services/sync/sync_codec.dart';
import '../services/sync/sync_write_executor.dart';
import '../utils/batched_change_notifier.dart';

class AssistantProvider extends ChangeNotifier with BatchedChangeNotifier {
  static const String _assistantsKey = 'assistants_v1';
  static const String _currentAssistantKey = 'current_assistant_id_v1';
  static const String _legacySearchEnabledKey = 'search_enabled_v1';
  static const String _defaultAssistantId =
      'c4f7b8e1-8f7b-4d2a-9c31-0e7d6a5b4001';
  static const String _sampleAssistantId =
      'c4f7b8e1-8f7b-4d2a-9c31-0e7d6a5b4002';

  final List<Assistant> _assistants = <Assistant>[];
  String? _currentAssistantId;
  final ChatService? chatService;
  final SyncWriteExecutor _syncWrites;
  final _AssistantMutationLock _localOperations = _AssistantMutationLock();
  final _AssistantMutationLock _mutations = _AssistantMutationLock();
  late final Future<void> ready;

  List<Assistant> get assistants => List.unmodifiable(_assistants);
  String? get currentAssistantId => _currentAssistantId;
  Assistant? get currentAssistant {
    final idx = _assistants.indexWhere((a) => a.id == _currentAssistantId);
    if (idx != -1) return _assistants[idx];
    if (_assistants.isNotEmpty) return _assistants.first;
    return null;
  }

  bool get currentSearchEnabled => currentAssistant?.searchEnabled ?? false;

  AssistantProvider({
    this.chatService,
    required SyncWriteExecutor syncWriteExecutor,
  }) : _syncWrites = syncWriteExecutor {
    ready = _mutations.run(_load);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_assistantsKey);
    var loaded = <Assistant>[];
    var changed = false;
    if (raw != null && raw.isNotEmpty) {
      final legacySearchEnabled = prefs.getBool(_legacySearchEnabledKey);
      final migrated = _decodeAssistantsWithLegacySearch(
        raw,
        legacySearchEnabled: legacySearchEnabled,
      );
      loaded = List<Assistant>.of(migrated.assistants);
      changed = migrated.didApplyLegacySearch;
      for (var i = 0; i < loaded.length; i++) {
        final assistant = loaded[i];
        String? av = assistant.avatar;
        String? bg = assistant.background;
        if (av != null &&
            av.isNotEmpty &&
            (av.startsWith('/') || av.contains(':')) &&
            !av.startsWith('http')) {
          final fixed = SandboxPathResolver.fix(av);
          if (fixed != av) {
            av = fixed;
            changed = true;
          }
        }
        if (bg != null &&
            bg.isNotEmpty &&
            (bg.startsWith('/') || bg.contains(':')) &&
            !bg.startsWith('http')) {
          final fixedBg = SandboxPathResolver.fix(bg);
          if (fixedBg != bg) {
            bg = fixedBg;
            changed = true;
          }
        }
        if (av != assistant.avatar || bg != assistant.background) {
          loaded[i] = assistant.copyWith(avatar: av, background: bg);
        }
      }
    }
    final savedId = prefs.getString(_currentAssistantKey);
    final currentAssistantId =
        savedId != null && loaded.any((assistant) => assistant.id == savedId)
        ? savedId
        : null;
    final state = _AssistantState(
      assistants: loaded,
      currentAssistantId: currentAssistantId,
    );
    if (changed) {
      await _writePreferencesTransaction(state);
    }
    _publishState(state);
  }

  _AssistantDecodeResult _decodeAssistantsWithLegacySearch(
    String raw, {
    required bool? legacySearchEnabled,
  }) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      bool didApplyLegacySearch = false;
      final assistants = [
        for (final e in decoded)
          if (e is Map)
            (() {
              final json = e.cast<String, dynamic>();
              if (legacySearchEnabled != null &&
                  !json.containsKey('searchEnabled')) {
                json['searchEnabled'] = legacySearchEnabled;
                didApplyLegacySearch = true;
              }
              return Assistant.fromJson(json);
            })(),
      ];
      return _AssistantDecodeResult(
        assistants: assistants,
        didApplyLegacySearch: didApplyLegacySearch,
      );
    } catch (_) {
      return const _AssistantDecodeResult(
        assistants: <Assistant>[],
        didApplyLegacySearch: false,
      );
    }
  }

  Assistant _defaultAssistant(AppLocalizations l10n) => Assistant(
    id: _defaultAssistantId,
    name: l10n.assistantProviderDefaultAssistantName,
    systemPrompt: '',
    thinkingBudget: null,
    temperature: 0.6,
    topP: null,
  );

  // 本地化就绪后再初始化默认助手，避免把临时占位名称写入持久配置。
  Future<void> ensureDefaults(dynamic context) async {
    final l10n = AppLocalizations.of(context)!;
    await ready;
    await _localOperations.run(() async {
      final shouldCreateDefaults = await _mutations.run(
        () async => _assistants.isEmpty,
      );
      if (!shouldCreateDefaults) return;
      final defaults = <Assistant>[
        _defaultAssistant(l10n),
        Assistant(
          id: _sampleAssistantId,
          name: l10n.assistantProviderSampleAssistantName,
          systemPrompt: l10n.assistantProviderSampleAssistantSystemPrompt(
            '{model_name}',
            '{cur_datetime}',
            '"{locale}"',
            '{timezone}',
            '{device_info}',
            '{system_version}',
          ),
          temperature: 0.6,
          topP: null,
        ),
      ];
      final keys = <SyncEntityKey>[
        ...defaults.map((assistant) => ConfigSyncKeys.assistant(assistant.id)),
        ConfigSyncKeys.assistantSelection,
      ];
      await _syncWrites.runLocalBatch(
        keys: keys,
        write: () => _mutations.run(() async {
          if (_assistants.isNotEmpty) return;
          await _commitAndPublish(
            _AssistantState(
              assistants: defaults,
              currentAssistantId: defaults.first.id,
            ),
          );
        }),
      );
    });
  }

  String _buildCopyName(Assistant source, AppLocalizations? l10n) {
    final suffix = (l10n?.assistantSettingsCopySuffix ?? 'Copy').trim();
    final baseName = source.name.trim().isEmpty
        ? (l10n?.assistantProviderNewAssistantName ?? 'Assistant')
        : source.name.trim();
    final existingNames = _assistants.map((a) => a.name).toSet();

    String candidate = suffix.isEmpty ? baseName : '$baseName $suffix';
    int counter = 2;
    while (existingNames.contains(candidate)) {
      final counterSuffix = suffix.isEmpty ? '$counter' : '$suffix $counter';
      candidate = '$baseName $counterSuffix';
      counter++;
    }
    return candidate;
  }

  Future<({String? value, String? createdManagedPath})> _duplicateLocalFile(
    String? rawPath, {
    required bool isAvatar,
    required String newId,
  }) async {
    final raw = (rawPath ?? '').trim();
    if (raw.isEmpty || raw.startsWith('http') || raw.startsWith('data:')) {
      return (value: rawPath, createdManagedPath: null);
    }
    final fixed = SandboxPathResolver.fix(raw);
    final src = File(fixed);
    if (!await src.exists()) {
      throw FileSystemException('待复制的助手资源不存在', fixed);
    }

    final dir = isAvatar
        ? await AppDirectories.getAvatarsDirectory()
        : await AppDirectories.getImagesDirectory();
    String ext = '';
    final dot = fixed.lastIndexOf('.');
    if (dot != -1 && dot < fixed.length - 1) {
      ext = fixed.substring(dot + 1).toLowerCase();
      if (ext.length > 6) ext = 'jpg';
    } else {
      ext = 'jpg';
    }
    final prefix = isAvatar ? 'assistant' : 'background';
    final dest = File(
      '${dir.path}/${prefix}_${newId}_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    try {
      await src.copy(dest.path);
    } catch (error, stackTrace) {
      await _deleteManagedFileIfOwned(
        dest.path,
        directoryAsync: isAvatar
            ? AppDirectories.getAvatarsDirectory
            : AppDirectories.getImagesDirectory,
        filenamePrefix: isAvatar ? 'assistant' : 'background',
        replacementPath: null,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
    return (value: dest.path, createdManagedPath: dest.path);
  }

  Future<({String? value, String? createdManagedPath})>
  _copyLocalAssetToManagedDirectory(
    String? rawPath, {
    required Future<Directory> Function() directoryAsync,
    required String filenamePrefix,
    required String id,
  }) async {
    final raw = (rawPath ?? '').trim();
    if (raw.isEmpty || raw.startsWith('http') || raw.startsWith('data:')) {
      return (value: rawPath, createdManagedPath: null);
    }
    if (!(raw.startsWith('/') || raw.contains(':'))) {
      return (value: rawPath, createdManagedPath: null);
    }

    final fixed = SandboxPathResolver.resolveUserSelectedSource(raw);
    final src = File(fixed);
    if (!await src.exists()) {
      throw StateError('assistant_asset_source_missing');
    }

    final managedDir = await directoryAsync();
    if (SandboxPathResolver.isOwnedManagedPath(
          path: src.path,
          managedDirectory: managedDir,
        ) &&
        p.basename(src.path).startsWith('${filenamePrefix}_')) {
      return (value: fixed, createdManagedPath: null);
    }

    var ext = p.extension(fixed).toLowerCase();
    if (ext.isEmpty || ext.length > 7) ext = '.jpg';
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final dest = File(
      p.join(
        managedDir.path,
        '${filenamePrefix}_${safeId}_${const Uuid().v4()}$ext',
      ),
    );
    try {
      await src.copy(dest.path);
    } catch (error, stackTrace) {
      await _deleteManagedFileIfOwned(
        dest.path,
        directoryAsync: directoryAsync,
        filenamePrefix: filenamePrefix,
        replacementPath: null,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
    return (value: dest.path, createdManagedPath: dest.path);
  }

  Future<void> _deleteManagedFileIfOwned(
    String? rawPath, {
    required Future<Directory> Function() directoryAsync,
    required String filenamePrefix,
    required String? replacementPath,
  }) async {
    final raw = (rawPath ?? '').trim();
    if (raw.isEmpty || raw.startsWith('http') || raw.startsWith('data:')) {
      return;
    }
    try {
      final dir = await directoryAsync();
      final targetFile = File(raw);
      final target = p.normalize(targetFile.absolute.path);
      if (!p.basename(target).startsWith('${filenamePrefix}_')) return;
      if (!SandboxPathResolver.isOwnedManagedPath(
        path: target,
        managedDirectory: dir,
      )) {
        return;
      }
      if (replacementPath != null &&
          p.equals(target, p.normalize(File(replacementPath).absolute.path))) {
        return;
      }
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'assistant_provider',
          context: ErrorDescription('清理旧助手资源失败'),
        ),
      );
    }
  }

  Future<void> _deleteManagedFileIfUnreferenced(
    String? rawPath, {
    required Future<Directory> Function() directoryAsync,
    required String filenamePrefix,
  }) async {
    final raw = (rawPath ?? '').trim();
    if (raw.isEmpty || raw.startsWith('http') || raw.startsWith('data:')) {
      return;
    }
    final target = p.normalize(File(raw).absolute.path);
    try {
      final managedDirectory = await directoryAsync();
      if (!SandboxPathResolver.isOwnedManagedPath(
        path: target,
        managedDirectory: managedDirectory,
      )) {
        return;
      }
      final targetIdentity = _resolveExistingFileIdentity(target);
      if (targetIdentity.uncertain || targetIdentity.path == null) return;
      for (final assistant in _assistants) {
        for (final rawCandidate in <String?>[
          assistant.avatar,
          assistant.background,
        ]) {
          final candidate = (rawCandidate ?? '').trim();
          if (candidate.isEmpty ||
              candidate.startsWith('http') ||
              candidate.startsWith('data:')) {
            continue;
          }
          final normalizedCandidate = p.normalize(
            File(candidate).absolute.path,
          );
          if (p.equals(target, normalizedCandidate)) return;
          final candidateIdentity = _resolveExistingFileIdentity(
            normalizedCandidate,
          );
          // 无法证明引用指向其他文件时宁可保留，避免清理动作打断现有引用。
          if (candidateIdentity.uncertain) return;
          if (candidateIdentity.path != null &&
              p.equals(targetIdentity.path!, candidateIdentity.path!)) {
            return;
          }
        }
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'assistant_provider',
          context: ErrorDescription('确认助手资源引用状态失败'),
        ),
      );
      return;
    }
    await _deleteManagedFileIfOwned(
      raw,
      directoryAsync: directoryAsync,
      filenamePrefix: filenamePrefix,
      replacementPath: null,
    );
  }

  ({String? path, bool uncertain}) _resolveExistingFileIdentity(String path) {
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return (path: null, uncertain: false);
      }
      final identity = SandboxPathResolver.canonicalExistingPathForComparison(
        path,
      );
      if (identity == null) return (path: null, uncertain: true);
      return (
        path: p.normalize(File(identity).absolute.path),
        uncertain: false,
      );
    } on FileSystemException {
      return (path: null, uncertain: true);
    } on ArgumentError {
      return (path: null, uncertain: true);
    }
  }

  Future<void> _cleanupCreatedCopies({
    required String? avatarPath,
    required String? backgroundPath,
  }) async {
    await _deleteManagedFileIfOwned(
      avatarPath,
      directoryAsync: AppDirectories.getAvatarsDirectory,
      filenamePrefix: 'assistant',
      replacementPath: null,
    );
    await _deleteManagedFileIfOwned(
      backgroundPath,
      directoryAsync: AppDirectories.getImagesDirectory,
      filenamePrefix: 'background',
      replacementPath: null,
    );
  }

  Future<void> _reloadPreferencesAfterFailedWrite(
    SharedPreferences prefs,
  ) async {
    try {
      // SharedPreferences 会先改内存缓存，失败后重载才能让读取结果回到磁盘事实。
      await prefs.reload();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'assistant_provider',
          context: ErrorDescription('助手配置写入失败后重载偏好缓存失败'),
        ),
      );
    }
  }

  Future<void> _requireSetString(
    SharedPreferences prefs,
    String key,
    String value,
  ) async {
    if (!await prefs.setString(key, value)) {
      throw StateError('助手配置持久化失败: $key');
    }
  }

  Future<void> _requireRemove(SharedPreferences prefs, String key) async {
    if (!await prefs.remove(key)) {
      throw StateError('助手配置删除失败: $key');
    }
  }

  Future<void> _restorePreferenceValue(
    SharedPreferences prefs, {
    required String key,
    required bool existed,
    required String? value,
  }) async {
    if (existed) {
      await _requireSetString(prefs, key, value!);
    } else {
      await _requireRemove(prefs, key);
    }
  }

  Future<void> _restorePreferences(
    SharedPreferences prefs,
    _StoredAssistantPreferences previous,
  ) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _restorePreferenceValue(
        prefs,
        key: _assistantsKey,
        existed: previous.hadAssistants,
        value: previous.assistants,
      );
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      await _restorePreferenceValue(
        prefs,
        key: _currentAssistantKey,
        existed: previous.hadCurrentAssistant,
        value: previous.currentAssistant,
      );
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  Future<void> _writePreferencesTransaction(_AssistantState next) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = _StoredAssistantPreferences(
      hadAssistants: prefs.containsKey(_assistantsKey),
      assistants: prefs.getString(_assistantsKey),
      hadCurrentAssistant: prefs.containsKey(_currentAssistantKey),
      currentAssistant: prefs.getString(_currentAssistantKey),
    );
    try {
      await _requireSetString(
        prefs,
        _assistantsKey,
        Assistant.encodeList(next.assistants),
      );
      final currentAssistantId = next.currentAssistantId;
      if (currentAssistantId == null) {
        await _requireRemove(prefs, _currentAssistantKey);
      } else {
        await _requireSetString(
          prefs,
          _currentAssistantKey,
          currentAssistantId,
        );
      }
    } catch (error, stackTrace) {
      try {
        await _restorePreferences(prefs, previous);
      } catch (rollbackError, rollbackStackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: rollbackError,
            stack: rollbackStackTrace,
            library: 'assistant_provider',
            context: ErrorDescription('回滚助手偏好事务失败'),
          ),
        );
      }
      await _reloadPreferencesAfterFailedWrite(prefs);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void _publishState(_AssistantState next) {
    _assistants
      ..clear()
      ..addAll(next.assistants);
    _currentAssistantId = next.currentAssistantId;
    notifyListeners();
  }

  Future<void> _commitAndPublish(_AssistantState next) async {
    await _writePreferencesTransaction(next);
    _publishState(next);
  }

  _AssistantState _currentState({List<Assistant>? assistants}) {
    return _AssistantState(
      assistants: assistants ?? List<Assistant>.of(_assistants),
      currentAssistantId: _currentAssistantId,
    );
  }

  Future<void> setCurrentAssistant(String id) async {
    await ready;
    await _localOperations.run(() async {
      final alreadyCurrent = await _mutations.run(
        () async => _currentAssistantId == id,
      );
      if (alreadyCurrent) return;
      await _syncWrites.runLocal(
        key: ConfigSyncKeys.assistantSelection,
        write: () => _mutations.run(() async {
          if (_currentAssistantId == id) return;
          await _commitAndPublish(
            _AssistantState(
              assistants: List<Assistant>.of(_assistants),
              currentAssistantId: id,
            ),
          );
        }),
      );
    });
  }

  Future<void> syncSetCurrentAssistant(String? id) async {
    await ready;
    await _mutations.run(() async {
      final nextId =
          id != null && _assistants.any((assistant) => assistant.id == id)
          ? id
          : null;
      if (_currentAssistantId == nextId) return;
      await _commitAndPublish(
        _AssistantState(
          assistants: List<Assistant>.of(_assistants),
          currentAssistantId: nextId,
        ),
      );
    });
  }

  Assistant? getById(String id) {
    final idx = _assistants.indexWhere((a) => a.id == id);
    if (idx == -1) return null;
    return _assistants[idx];
  }

  // 让调用方无需依赖 Assistant.presetMessages 的具体模型类型。
  List<Map<String, String>> getPresetMessagesForAssistant(String? assistantId) {
    Assistant? a;
    if (assistantId != null) {
      a = getById(assistantId);
    } else {
      a = currentAssistant;
    }
    if (a == null) return const <Map<String, String>>[];
    return [
      for (final m in a.presetMessages) {'role': m.role, 'content': m.content},
    ];
  }

  Future<String> addAssistant({String? name, dynamic context}) async {
    await ready;
    return _localOperations.run(() async {
      final assistant = Assistant(
        id: const Uuid().v4(),
        name:
            (name ??
            (context != null
                ? AppLocalizations.of(
                    context,
                  )!.assistantProviderNewAssistantName
                : 'New Assistant')),
        temperature: 0.6,
        topP: null,
      );
      return _syncWrites.runLocal(
        key: ConfigSyncKeys.assistant(assistant.id),
        write: () => _mutations.run(() async {
          final nextAssistants = List<Assistant>.of(_assistants)
            ..add(assistant);
          await _commitAndPublish(_currentState(assistants: nextAssistants));
          return assistant.id;
        }),
      );
    });
  }

  Future<String?> duplicateAssistant(
    String id, {
    AppLocalizations? l10n,
  }) async {
    await ready;
    return _localOperations.run(() async {
      final snapshot = await _mutations.run(() async {
        final index = _assistants.indexWhere((assistant) => assistant.id == id);
        if (index == -1) return null;
        return (
          index: index,
          assistantIds: _assistants
              .map((assistant) => assistant.id)
              .toList(growable: false),
        );
      });
      if (snapshot == null) return null;
      final newId = const Uuid().v4();
      final keys = <SyncEntityKey>[
        ConfigSyncKeys.assistant(newId),
        ...snapshot.assistantIds
            .skip(snapshot.index + 1)
            .map(ConfigSyncKeys.assistant),
      ];
      return _syncWrites.runLocalBatch(
        keys: keys,
        write: () => _mutations.run(() async {
          final currentIndex = _assistants.indexWhere(
            (assistant) => assistant.id == id,
          );
          if (currentIndex == -1) return null;
          final source = _assistants[currentIndex];
          ({String? value, String? createdManagedPath}) avatarCopy = (
            value: source.avatar,
            createdManagedPath: null,
          );
          ({String? value, String? createdManagedPath}) backgroundCopy = (
            value: source.background,
            createdManagedPath: null,
          );

          try {
            avatarCopy = await _duplicateLocalFile(
              source.avatar,
              isAvatar: true,
              newId: newId,
            );
            backgroundCopy = await _duplicateLocalFile(
              source.background,
              isAvatar: false,
              newId: newId,
            );
            final copy = source.copyWith(
              id: newId,
              name: _buildCopyName(source, l10n),
              avatar: avatarCopy.value,
              background: backgroundCopy.value,
              mcpServerIds: List<String>.of(source.mcpServerIds),
              localToolIds: List<String>.of(source.localToolIds),
              customHeaders: source.customHeaders
                  .map((e) => Map<String, String>.from(e))
                  .toList(),
              customBody: source.customBody
                  .map((e) => Map<String, String>.from(e))
                  .toList(),
              presetMessages: source.presetMessages
                  .map((m) => PresetMessage(role: m.role, content: m.content))
                  .toList(),
              regexRules: source.regexRules
                  .map(
                    (r) => AssistantRegex(
                      id: const Uuid().v4(),
                      name: r.name,
                      pattern: r.pattern,
                      replacement: r.replacement,
                      scopes: List<AssistantRegexScope>.of(r.scopes),
                      visualOnly: r.visualOnly,
                      replaceOnly: r.replaceOnly,
                      enabled: r.enabled,
                    ),
                  )
                  .toList(),
            );
            final nextAssistants = List<Assistant>.of(_assistants)
              ..insert(currentIndex + 1, copy);
            await _commitAndPublish(_currentState(assistants: nextAssistants));
            return copy.id;
          } catch (error, stackTrace) {
            await _cleanupCreatedCopies(
              avatarPath: avatarCopy.createdManagedPath,
              backgroundPath: backgroundCopy.createdManagedPath,
            );
            Error.throwWithStackTrace(error, stackTrace);
          }
        }),
      );
    });
  }

  Future<void> updateAssistant(Assistant updated) async {
    await ready;
    await _localOperations.run(() async {
      await _syncWrites.runLocal<void>(
        key: ConfigSyncKeys.assistant(updated.id),
        write: () => _mutations.run(() async {
          final idx = _assistants.indexWhere(
            (assistant) => assistant.id == updated.id,
          );
          if (idx == -1) return;
          final previous = _assistants[idx];
          final rawAvatar = (updated.avatar ?? '').trim();
          final previousAvatar = (previous.avatar ?? '').trim();
          final avatarChanged = rawAvatar != previousAvatar;
          final rawBackground = (updated.background ?? '').trim();
          final previousBackground = (previous.background ?? '').trim();
          final backgroundChanged = rawBackground != previousBackground;
          ({String? value, String? createdManagedPath}) avatarResult = (
            value: updated.avatar,
            createdManagedPath: null,
          );
          ({String? value, String? createdManagedPath}) backgroundResult = (
            value: updated.background,
            createdManagedPath: null,
          );
          try {
            if (avatarChanged) {
              avatarResult = await _copyLocalAssetToManagedDirectory(
                updated.avatar,
                directoryAsync: AppDirectories.getAvatarsDirectory,
                filenamePrefix: 'assistant',
                id: updated.id,
              );
            }
            if (backgroundChanged) {
              backgroundResult = await _copyLocalAssetToManagedDirectory(
                updated.background,
                directoryAsync: AppDirectories.getImagesDirectory,
                filenamePrefix: 'background',
                id: updated.id,
              );
            }
          } catch (error, stackTrace) {
            await _deleteManagedFileIfOwned(
              avatarResult.createdManagedPath,
              directoryAsync: AppDirectories.getAvatarsDirectory,
              filenamePrefix: 'assistant',
              replacementPath: null,
            );
            await _deleteManagedFileIfOwned(
              backgroundResult.createdManagedPath,
              directoryAsync: AppDirectories.getImagesDirectory,
              filenamePrefix: 'background',
              replacementPath: null,
            );
            Error.throwWithStackTrace(error, stackTrace);
          }

          final next = updated.copyWith(
            avatar: avatarResult.value,
            background: backgroundResult.value,
            clearAvatar: avatarResult.value == null,
            clearBackground: backgroundResult.value == null,
          );
          final nextAssistants = List<Assistant>.of(_assistants);
          nextAssistants[idx] = next;
          try {
            await _commitAndPublish(_currentState(assistants: nextAssistants));
          } catch (error, stackTrace) {
            await _deleteManagedFileIfOwned(
              avatarResult.createdManagedPath,
              directoryAsync: AppDirectories.getAvatarsDirectory,
              filenamePrefix: 'assistant',
              replacementPath: null,
            );
            await _deleteManagedFileIfOwned(
              backgroundResult.createdManagedPath,
              directoryAsync: AppDirectories.getImagesDirectory,
              filenamePrefix: 'background',
              replacementPath: null,
            );
            Error.throwWithStackTrace(error, stackTrace);
          }

          if (avatarChanged) {
            await _deleteManagedFileIfUnreferenced(
              previousAvatar,
              directoryAsync: AppDirectories.getAvatarsDirectory,
              filenamePrefix: 'assistant',
            );
          }
          if (backgroundChanged) {
            await _deleteManagedFileIfUnreferenced(
              previousBackground,
              directoryAsync: AppDirectories.getImagesDirectory,
              filenamePrefix: 'background',
            );
          }
          if (avatarChanged && rawAvatar.startsWith('http')) {
            try {
              await AvatarCache.getPath(rawAvatar);
            } catch (error, stackTrace) {
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: error,
                  stack: stackTrace,
                  library: 'assistant_provider',
                  context: ErrorDescription('预取助手头像失败'),
                ),
              );
            }
          }
        }),
      );
    });
  }

  Future<void> syncUpsertAssistant(
    Assistant assistant, {
    required int position,
  }) async {
    await ready;
    await _mutations.run(() async {
      final currentIndex = _assistants.indexWhere(
        (candidate) => candidate.id == assistant.id,
      );
      final previous = currentIndex >= 0 ? _assistants[currentIndex] : null;
      final nextAssistants = List<Assistant>.of(_assistants);
      if (currentIndex >= 0) {
        nextAssistants.removeAt(currentIndex);
      }
      final target = position.clamp(0, nextAssistants.length);
      nextAssistants.insert(target, assistant);
      await _commitAndPublish(_currentState(assistants: nextAssistants));
      if (previous != null && previous.avatar != assistant.avatar) {
        await _deleteManagedFileIfUnreferenced(
          previous.avatar,
          directoryAsync: AppDirectories.getAvatarsDirectory,
          filenamePrefix: 'assistant',
        );
      }
      if (previous != null && previous.background != assistant.background) {
        await _deleteManagedFileIfUnreferenced(
          previous.background,
          directoryAsync: AppDirectories.getImagesDirectory,
          filenamePrefix: 'background',
        );
      }
    });
  }

  Future<void> syncDeleteAssistant(String id) async {
    await ready;
    await _mutations.run(() async {
      final index = _assistants.indexWhere((assistant) => assistant.id == id);
      if (index == -1) return;
      final removed = _assistants[index];
      final nextAssistants = List<Assistant>.of(_assistants)..removeAt(index);
      final nextCurrentId = _currentAssistantId == id
          ? (nextAssistants.isEmpty ? null : nextAssistants.first.id)
          : _currentAssistantId;
      await _commitAndPublish(
        _AssistantState(
          assistants: nextAssistants,
          currentAssistantId: nextCurrentId,
        ),
      );
      await _deleteManagedFileIfUnreferenced(
        removed.avatar,
        directoryAsync: AppDirectories.getAvatarsDirectory,
        filenamePrefix: 'assistant',
      );
      await _deleteManagedFileIfUnreferenced(
        removed.background,
        directoryAsync: AppDirectories.getImagesDirectory,
        filenamePrefix: 'background',
      );
    });
  }

  Future<void> setSearchEnabledForCurrentAssistant(bool enabled) async {
    await ready;
    await _localOperations.run(() async {
      final current = await _mutations.run(() async => currentAssistant);
      if (current == null || current.searchEnabled == enabled) return;
      await _syncWrites.runLocal(
        key: ConfigSyncKeys.assistant(current.id),
        write: () => _mutations.run(() async {
          final latest = getById(current.id);
          if (latest == null || latest.searchEnabled == enabled) return;
          final index = _assistants.indexWhere(
            (assistant) => assistant.id == current.id,
          );
          final nextAssistants = List<Assistant>.of(_assistants);
          nextAssistants[index] = latest.copyWith(searchEnabled: enabled);
          await _commitAndPublish(_currentState(assistants: nextAssistants));
        }),
      );
    });
  }

  Future<void> reorderAssistantRegex({
    required String assistantId,
    required int oldIndex,
    required int newIndex,
  }) async {
    await ready;
    await _localOperations.run(() async {
      final plan = await _mutations.run(() async {
        final index = _assistants.indexWhere(
          (assistant) => assistant.id == assistantId,
        );
        if (index == -1) return null;
        final rules = _assistants[index].regexRules;
        if (oldIndex < 0 || oldIndex >= rules.length) return null;
        if (newIndex < 0 || newIndex >= rules.length) return null;
        if (oldIndex == newIndex) return null;
        return (
          movedId: rules[oldIndex].id,
          anchorId: rules[newIndex].id,
          insertAfterAnchor: oldIndex < newIndex,
        );
      });
      if (plan == null) return;
      await _syncWrites.runLocal(
        key: ConfigSyncKeys.assistant(assistantId),
        write: () => _mutations.run(() async {
          final latestIndex = _assistants.indexWhere(
            (assistant) => assistant.id == assistantId,
          );
          if (latestIndex == -1) return;
          final latestRules = List<AssistantRegex>.of(
            _assistants[latestIndex].regexRules,
          );
          final movedIndex = latestRules.indexWhere(
            (rule) => rule.id == plan.movedId,
          );
          if (movedIndex == -1) return;
          final moved = latestRules.removeAt(movedIndex);
          final anchorIndex = latestRules.indexWhere(
            (rule) => rule.id == plan.anchorId,
          );
          if (anchorIndex == -1) return;
          final insertionIndex = plan.insertAfterAnchor
              ? anchorIndex + 1
              : anchorIndex;
          latestRules.insert(insertionIndex, moved);
          final nextAssistants = List<Assistant>.of(_assistants);
          nextAssistants[latestIndex] = _assistants[latestIndex].copyWith(
            regexRules: latestRules,
          );
          await _commitAndPublish(_currentState(assistants: nextAssistants));
        }),
      );
    });
  }

  Future<bool> deleteAssistant(String id) async {
    await ready;
    return _localOperations.run(() async {
      final snapshot = await _mutations.run(() async {
        final index = _assistants.indexWhere((assistant) => assistant.id == id);
        if (index == -1 || _assistants.length <= 1) return null;
        return (
          index: index,
          assistantIds: _assistants
              .map((assistant) => assistant.id)
              .toList(growable: false),
        );
      });
      if (snapshot == null) return false;
      final keys = <SyncEntityKey>[
        ...snapshot.assistantIds
            .skip(snapshot.index)
            .map(ConfigSyncKeys.assistant),
        ConfigSyncKeys.assistantSelection,
      ];
      await chatService?.deleteConversationsForAssistant(id);
      return _syncWrites.runLocalBatch(
        keys: keys,
        write: () => _mutations.run(() async {
          final latestIndex = _assistants.indexWhere(
            (assistant) => assistant.id == id,
          );
          if (latestIndex == -1) return true;
          final removed = _assistants[latestIndex];
          final nextAssistants = List<Assistant>.of(_assistants)
            ..removeAt(latestIndex);
          final nextCurrentId = _currentAssistantId == id
              ? (nextAssistants.isEmpty ? null : nextAssistants.first.id)
              : _currentAssistantId;
          await _commitAndPublish(
            _AssistantState(
              assistants: nextAssistants,
              currentAssistantId: nextCurrentId,
            ),
          );
          await _deleteManagedFileIfUnreferenced(
            removed.avatar,
            directoryAsync: AppDirectories.getAvatarsDirectory,
            filenamePrefix: 'assistant',
          );
          await _deleteManagedFileIfUnreferenced(
            removed.background,
            directoryAsync: AppDirectories.getImagesDirectory,
            filenamePrefix: 'background',
          );
          return true;
        }),
      );
    });
  }

  Future<void> reorderAssistants(int oldIndex, int newIndex) async {
    await ready;
    await _localOperations.run(() async {
      final plan = await _mutations.run(() async {
        if (oldIndex == newIndex) return null;
        if (oldIndex < 0 || oldIndex >= _assistants.length) return null;
        if (newIndex < 0 || newIndex >= _assistants.length) return null;
        final start = oldIndex < newIndex ? oldIndex : newIndex;
        final end = oldIndex > newIndex ? oldIndex : newIndex;
        return (
          keys: _assistants
              .sublist(start, end + 1)
              .map((assistant) => ConfigSyncKeys.assistant(assistant.id))
              .toList(growable: false),
          movedId: _assistants[oldIndex].id,
          anchorId: _assistants[newIndex].id,
          insertAfterAnchor: oldIndex < newIndex,
        );
      });
      if (plan == null) return;
      await _syncWrites.runLocalBatch(
        keys: plan.keys,
        write: () => _mutations.run(() async {
          final nextAssistants = List<Assistant>.of(_assistants);
          final movedIndex = nextAssistants.indexWhere(
            (assistant) => assistant.id == plan.movedId,
          );
          if (movedIndex == -1) return;
          final moved = nextAssistants.removeAt(movedIndex);
          final anchorIndex = nextAssistants.indexWhere(
            (assistant) => assistant.id == plan.anchorId,
          );
          if (anchorIndex == -1) return;
          // 远端可在等待实体锁期间插入其他助手，排序意图必须绑定调用时的助手身份。
          final insertionIndex = plan.insertAfterAnchor
              ? anchorIndex + 1
              : anchorIndex;
          nextAssistants.insert(insertionIndex, moved);
          await _commitAndPublish(_currentState(assistants: nextAssistants));
        }),
      );
    });
  }

  // 子集顺序只替换其原有槽位，其他助手的位置必须保持不变。
  Future<void> reorderAssistantsWithin({
    required List<String> subsetIds,
    required int oldIndex,
    required int newIndex,
  }) async {
    await ready;
    await _localOperations.run(() async {
      final idSet = subsetIds.toSet();
      final plan = await _mutations.run(() async {
        if (oldIndex == newIndex || idSet.isEmpty) return null;
        final subsetIndices = <int>[];
        for (var i = 0; i < _assistants.length; i++) {
          if (idSet.contains(_assistants[i].id)) subsetIndices.add(i);
        }
        if (subsetIndices.isEmpty) return null;
        if (oldIndex < 0 || oldIndex >= subsetIndices.length) return null;
        if (newIndex < 0 || newIndex >= subsetIndices.length) return null;
        final subset = subsetIndices
            .map((index) => _assistants[index])
            .toList(growable: false);
        final start = oldIndex < newIndex ? oldIndex : newIndex;
        final end = oldIndex > newIndex ? oldIndex : newIndex;
        return (
          keys: subset
              .sublist(start, end + 1)
              .map((assistant) => ConfigSyncKeys.assistant(assistant.id))
              .toList(growable: false),
          movedId: subset[oldIndex].id,
          anchorId: subset[newIndex].id,
          insertAfterAnchor: oldIndex < newIndex,
        );
      });
      if (plan == null) return;
      await _syncWrites.runLocalBatch(
        keys: plan.keys,
        write: () => _mutations.run(() async {
          final latestSubset = _assistants
              .where((assistant) => idSet.contains(assistant.id))
              .toList(growable: true);
          final movedIndex = latestSubset.indexWhere(
            (assistant) => assistant.id == plan.movedId,
          );
          if (movedIndex == -1) return;
          final moved = latestSubset.removeAt(movedIndex);
          final anchorIndex = latestSubset.indexWhere(
            (assistant) => assistant.id == plan.anchorId,
          );
          if (anchorIndex == -1) return;
          final insertionIndex = plan.insertAfterAnchor
              ? anchorIndex + 1
              : anchorIndex;
          latestSubset.insert(insertionIndex, moved);
          final merged = <Assistant>[];
          var take = 0;
          for (final assistant in _assistants) {
            if (idSet.contains(assistant.id)) {
              merged.add(latestSubset[take++]);
            } else {
              merged.add(assistant);
            }
          }
          await _commitAndPublish(_currentState(assistants: merged));
        }),
      );
    });
  }
}

final class _AssistantMutationLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) async {
    final previous = _tail;
    final completed = Completer<void>();
    _tail = completed.future;
    await previous;
    try {
      return await action();
    } finally {
      completed.complete();
    }
  }
}

final class _AssistantState {
  _AssistantState({
    required List<Assistant> assistants,
    required this.currentAssistantId,
  }) : assistants = List<Assistant>.unmodifiable(assistants);

  final List<Assistant> assistants;
  final String? currentAssistantId;
}

final class _StoredAssistantPreferences {
  const _StoredAssistantPreferences({
    required this.hadAssistants,
    required this.assistants,
    required this.hadCurrentAssistant,
    required this.currentAssistant,
  });

  final bool hadAssistants;
  final String? assistants;
  final bool hadCurrentAssistant;
  final String? currentAssistant;
}

class _AssistantDecodeResult {
  const _AssistantDecodeResult({
    required this.assistants,
    required this.didApplyLegacySearch,
  });

  final List<Assistant> assistants;
  final bool didApplyLegacySearch;
}
