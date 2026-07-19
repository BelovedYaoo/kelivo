import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../utils/sandbox_path_resolver.dart';
import '../../utils/avatar_cache.dart';
import '../../utils/app_directories.dart';
import '../services/sync/config_sync_keys.dart';
import '../services/sync/sync_write_executor.dart';
import '../utils/batched_change_notifier.dart';

typedef _ManagedFileCopy = Future<void> Function(File source, File destination);

const String _providerConfigsPreferenceKey = 'provider_configs_v1';

final RegExp _managedUserAvatarFileName = RegExp(
  r'^avatar_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.[a-z0-9]{1,6}$',
);

class UserProvider extends ChangeNotifier with BatchedChangeNotifier {
  static const String _prefsUserNameKey = 'user_name';
  static const String _prefsAvatarTypeKey =
      'avatar_type'; // emoji | url | file | null
  static const String _prefsAvatarValueKey = 'avatar_value';

  String _name = 'User';
  String get name => _name;
  bool _hasSavedName = false;

  String? _avatarType; // 'emoji', 'url', 'file'
  String? _avatarValue;
  String? get avatarType => _avatarType;
  String? get avatarValue => _avatarValue;
  late final Future<void> ready;
  final SyncWriteExecutor _syncWrites;
  final _ManagedFileCopy _managedFileCopy;

  UserProvider({required SyncWriteExecutor syncWriteExecutor})
    : this._(syncWriteExecutor: syncWriteExecutor);

  @visibleForTesting
  factory UserProvider.forTesting({
    required SyncWriteExecutor syncWriteExecutor,
    Future<void> Function(File source, File destination)? managedFileCopy,
  }) {
    return UserProvider._(
      syncWriteExecutor: syncWriteExecutor,
      managedFileCopy: managedFileCopy,
    );
  }

  UserProvider._({
    required SyncWriteExecutor syncWriteExecutor,
    _ManagedFileCopy? managedFileCopy,
  }) : _syncWrites = syncWriteExecutor,
       _managedFileCopy = managedFileCopy ?? _copyManagedFile {
    ready = _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getString(_prefsUserNameKey);
    if (n != null && n.isNotEmpty) {
      _name = n;
      _hasSavedName = true;
      notifyListeners();
    }
    _avatarType = prefs.getString(_prefsAvatarTypeKey);
    final rawAvatar = prefs.getString(_prefsAvatarValueKey);
    _avatarValue = rawAvatar == null
        ? null
        : SandboxPathResolver.fix(rawAvatar);
    // Persist the fixed path back if it changed (helps desktop after imports)
    if (rawAvatar != null &&
        _avatarValue != null &&
        rawAvatar != _avatarValue) {
      await _writePreferencesAtomically(prefs, <String, Object?>{
        _prefsAvatarValueKey: _avatarValue,
      }, operation: '修正用户头像路径');
    }
    // Only notify if avatar exists; otherwise rely on name notify above
    if (_avatarType != null && _avatarValue != null) {
      notifyListeners();
    }
  }

  // Set localized default name if user hasn't saved a custom one
  void setDefaultNameIfUnset(String localizedDefaultName) {
    if (_hasSavedName) return;
    final v = localizedDefaultName.trim();
    if (v.isEmpty) return;
    if (_name != v) {
      _name = v;
      notifyListeners();
    }
  }

  Future<void> setName(String name) async {
    await ready;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _name) return;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.profile,
      write: () async {
        final prefs = await SharedPreferences.getInstance();
        await _writePreferencesAtomically(prefs, <String, Object?>{
          _prefsUserNameKey: trimmed,
        }, operation: '保存用户名');
        _name = trimmed;
        _hasSavedName = true;
        notifyListeners();
      },
    );
  }

  Future<void> setAvatarEmoji(String emoji) async {
    await ready;
    final e = emoji.trim();
    if (e.isEmpty) return;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.profile,
      write: () async {
        await _setAvatarStateLocked(type: 'emoji', value: e);
      },
    );
  }

  Future<void> setAvatarUrl(String url) async {
    await ready;
    final u = url.trim();
    if (u.isEmpty) return;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.profile,
      write: () async {
        await _setAvatarStateLocked(type: 'url', value: u);
      },
    );
    // Prefetch to enable offline display later
    try {
      await AvatarCache.getPath(u);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'user_provider',
          context: ErrorDescription('预取用户头像失败'),
        ),
      );
    }
  }

  Future<void> setAvatarFilePath(String path) async {
    await ready;
    final selectedPath = path.trim();
    if (selectedPath.isEmpty) return;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.profile,
      write: () async {
        final fixedInput = SandboxPathResolver.resolveUserSelectedSource(
          selectedPath,
        );
        final src = File(fixedInput);
        if (!await src.exists()) {
          throw FileSystemException('选择的用户头像文件不存在', fixedInput);
        }
        final avatars = await AppDirectories.getAvatarsDirectory();
        if (!await avatars.exists()) {
          await avatars.create(recursive: true);
        }
        final selectedExtension = p
            .extension(p.basename(fixedInput))
            .replaceFirst('.', '')
            .toLowerCase();
        final ext =
            selectedExtension.isNotEmpty &&
                selectedExtension.length <= 6 &&
                RegExp(r'^[a-z0-9]+$').hasMatch(selectedExtension)
            ? selectedExtension
            : 'jpg';
        final filename = 'avatar_${const Uuid().v4()}.$ext';
        final dest = File(p.join(avatars.path, filename));
        try {
          await _managedFileCopy(src, dest);
          await _setAvatarStateLocked(type: 'file', value: dest.path);
        } catch (error, stackTrace) {
          await _deleteManagedAvatarIfUnused(
            dest.path,
            context: '清理未提交的用户头像副本失败',
          );
          Error.throwWithStackTrace(error, stackTrace);
        }
      },
    );
  }

  Future<void> resetAvatar() async {
    await ready;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.profile,
      write: () async {
        if (_avatarType == null && _avatarValue == null) return;
        await _setAvatarStateLocked(type: null, value: null);
      },
    );
  }

  Future<void> _setAvatarStateLocked({
    required String? type,
    required String? value,
  }) async {
    final previousAvatarPath = _avatarType == 'file' ? _avatarValue : null;
    final prefs = await SharedPreferences.getInstance();
    await _writePreferencesAtomically(prefs, <String, Object?>{
      _prefsAvatarValueKey: value,
      _prefsAvatarTypeKey: type,
    }, operation: '保存用户头像');
    _avatarType = type;
    _avatarValue = value;
    notifyListeners();
    await _deleteManagedAvatarIfUnused(
      previousAvatarPath,
      context: '清理旧用户头像失败',
    );
  }

  Future<void> _deleteManagedAvatarIfUnused(
    String? path, {
    required String context,
  }) async {
    if (path == null || path.isEmpty) return;
    if (_avatarType == 'file' &&
        _avatarValue != null &&
        p.equals(p.normalize(_avatarValue!), p.normalize(path))) {
      return;
    }
    try {
      final avatars = await AppDirectories.getAvatarsDirectory();
      final file = File(path);
      if (_managedUserAvatarFileName.hasMatch(p.basename(file.path)) &&
          SandboxPathResolver.isOwnedManagedPath(
            path: file.path,
            managedDirectory: avatars,
          )) {
        if (await _isReferencedByProviderConfiguration(file.path)) return;
        if (!await file.exists()) return;
        await file.delete();
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'user_provider',
          context: ErrorDescription(context),
        ),
      );
    }
  }

  Future<bool> _isReferencedByProviderConfiguration(String path) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_providerConfigsPreferenceKey);
    if (encoded == null || encoded.isEmpty) return false;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<Object?, Object?>) return true;
      final normalizedPath = p.normalize(p.absolute(path));
      for (final value in decoded.values) {
        if (value is! Map<Object?, Object?>) return true;
        final avatarValue = value['avatarValue'];
        if (avatarValue is String &&
            p.equals(p.normalize(p.absolute(avatarValue)), normalizedPath)) {
          return true;
        }
      }
      return false;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'user_provider',
          context: ErrorDescription('检查供应商头像引用失败'),
        ),
      );
      return true;
    }
  }

  Future<void> syncApplyProfile({
    required String name,
    required bool replaceAvatar,
    String? avatarType,
    String? avatarValue,
  }) async {
    await ready;
    final normalizedName = name.trim();
    final nextName = normalizedName.isEmpty ? _name : normalizedName;
    final nextAvatarType = replaceAvatar ? avatarType : _avatarType;
    final nextAvatarValue = replaceAvatar ? avatarValue : _avatarValue;
    final previousAvatarPath = _avatarType == 'file' ? _avatarValue : null;
    final prefs = await SharedPreferences.getInstance();
    await _writePreferencesAtomically(prefs, <String, Object?>{
      _prefsUserNameKey: nextName,
      _prefsAvatarValueKey: nextAvatarValue,
      _prefsAvatarTypeKey: nextAvatarType,
    }, operation: '同步用户资料');
    if (normalizedName.isNotEmpty) {
      _name = normalizedName;
      _hasSavedName = true;
    }
    if (replaceAvatar) {
      _avatarType = avatarType;
      _avatarValue = avatarValue;
    }
    notifyListeners();
    await _deleteManagedAvatarIfUnused(
      previousAvatarPath,
      context: '同步后清理旧用户头像失败',
    );
  }
}

Future<void> _copyManagedFile(File source, File destination) async {
  await source.copy(destination.path);
}

Future<void> _writePreferencesAtomically(
  SharedPreferences preferences,
  Map<String, Object?> values, {
  required String operation,
}) async {
  final previousValues = <String, Object?>{
    for (final key in values.keys) key: preferences.get(key),
  };
  try {
    for (final entry in values.entries) {
      final succeeded = await _writePreferenceValue(
        preferences,
        entry.key,
        entry.value,
      );
      if (!succeeded) {
        throw StateError('$operation失败：${entry.key} 未写入');
      }
    }
  } catch (error, stackTrace) {
    Object? rollbackError;
    for (final entry in previousValues.entries) {
      try {
        final succeeded = await _writePreferenceValue(
          preferences,
          entry.key,
          entry.value,
        );
        if (!succeeded) {
          rollbackError ??= StateError('$operation回滚失败：${entry.key}');
        }
      } catch (error) {
        rollbackError ??= error;
      }
    }
    try {
      await preferences.reload();
    } catch (error) {
      rollbackError ??= error;
    }
    if (rollbackError != null) {
      throw StateError('$operation失败且偏好回滚未完成：$rollbackError');
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

Future<bool> _writePreferenceValue(
  SharedPreferences preferences,
  String key,
  Object? value,
) {
  if (value == null) return preferences.remove(key);
  if (value is String) return preferences.setString(key, value);
  if (value is bool) return preferences.setBool(key, value);
  if (value is int) return preferences.setInt(key, value);
  if (value is double) return preferences.setDouble(key, value);
  if (value is List<String>) {
    return preferences.setStringList(key, value);
  }
  throw ArgumentError.value(value, key, '不支持的偏好值类型');
}
