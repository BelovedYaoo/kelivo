import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../utils/sandbox_path_resolver.dart';
import '../../utils/avatar_cache.dart';
import '../../utils/app_directories.dart';
import '../services/sync/config_sync_keys.dart';
import '../services/sync/sync_write_executor.dart';
import '../utils/batched_change_notifier.dart';
export '../services/sync/sync_write_executor.dart'
    show UntrackedSyncWriteExecutor;

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

  UserProvider({required SyncWriteExecutor syncWriteExecutor})
    : _syncWrites = syncWriteExecutor {
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
      try {
        await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
      } catch (_) {}
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
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _name) return;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.profile,
      write: () async {
        _name = trimmed;
        _hasSavedName = true;
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsUserNameKey, _name);
      },
    );
  }

  Future<void> setAvatarEmoji(String emoji) async {
    final e = emoji.trim();
    if (e.isEmpty) return;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.profile,
      write: () async {
        _avatarType = 'emoji';
        _avatarValue = e;
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
        await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
      },
    );
  }

  Future<void> setAvatarUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.profile,
      write: () async {
        _avatarType = 'url';
        _avatarValue = u;
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
        await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
      },
    );
    // Prefetch to enable offline display later
    try {
      await AvatarCache.getPath(u);
    } catch (_) {}
  }

  Future<void> setAvatarFilePath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.profile,
      write: () async {
        final fixedInput = SandboxPathResolver.fix(p);
        // 头像文件和资料索引必须处于同一个写前保护区，避免文件落盘后资料写入失踪。
        try {
          final src = File(fixedInput);
          if (!await src.exists()) return;
          final avatars = await AppDirectories.getAvatarsDirectory();
          if (!await avatars.exists()) {
            await avatars.create(recursive: true);
          }
          String ext = '';
          final dot = fixedInput.lastIndexOf('.');
          if (dot != -1 && dot < p.length - 1) {
            ext = fixedInput.substring(dot + 1).toLowerCase();
            if (ext.length > 6) ext = 'jpg';
          } else {
            ext = 'jpg';
          }
          final filename =
              'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final dest = File('${avatars.path}/$filename');
          await src.copy(dest.path);

          if (_avatarType == 'file' && _avatarValue != null) {
            try {
              final old = File(_avatarValue!);
              if ((old.path.contains('/avatars/') ||
                      old.path.contains('\\avatars\\')) &&
                  await old.exists()) {
                await old.delete();
              }
            } catch (_) {}
          }

          _avatarType = 'file';
          _avatarValue = dest.path;
          notifyListeners();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
          await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
        } catch (_) {
          _avatarType = 'file';
          _avatarValue = fixedInput;
          notifyListeners();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
          await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
        }
      },
    );
  }

  Future<void> resetAvatar() async {
    if (_avatarType == null && _avatarValue == null) return;
    await _syncWrites.runLocal(
      key: ConfigSyncKeys.profile,
      write: () async {
        _avatarType = null;
        _avatarValue = null;
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsAvatarTypeKey);
        await prefs.remove(_prefsAvatarValueKey);
      },
    );
  }

  Future<void> syncApplyProfile({
    required String name,
    required bool replaceAvatar,
    String? avatarType,
    String? avatarValue,
  }) async {
    await ready;
    final normalizedName = name.trim();
    if (normalizedName.isNotEmpty) {
      _name = normalizedName;
      _hasSavedName = true;
    }
    if (replaceAvatar) {
      _avatarType = avatarType;
      _avatarValue = avatarValue;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUserNameKey, _name);
    if (_avatarType == null || _avatarValue == null) {
      await prefs.remove(_prefsAvatarTypeKey);
      await prefs.remove(_prefsAvatarValueKey);
    } else {
      await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
      await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
    }
    notifyListeners();
  }
}
