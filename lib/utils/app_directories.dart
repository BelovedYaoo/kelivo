import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Platform-specific application data directory utilities.
///
/// - Windows/macOS/Linux: use the Application Support (app data) directory
///   provided by `path_provider`.
/// - Android/iOS: keep using the Application Documents directory.
class AppDirectories {
  AppDirectories._();

  static Directory? _installationRoot;
  static Directory? _workspaceRoot;
  static String? _canonicalWorkspaceRoot;
  static bool _accountWorkspace = false;

  /// 取得不受账号工作区影响的平台安装根目录。
  static Future<Directory> getInstallationRootDirectory() async {
    final boundRoot = _installationRoot;
    if (boundRoot != null) return boundRoot;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return getApplicationSupportDirectory();
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return getApplicationDocumentsDirectory();
    }
  }

  /// 在任何业务存储初始化前绑定本进程唯一的工作区。
  static void bindWorkspaceRoot(
    Directory directory, {
    Directory? installationRoot,
    required bool accountWorkspace,
    String? canonicalWorkspaceRoot,
  }) {
    _installationRoot = Directory(
      (installationRoot ?? directory).absolute.path,
    );
    final workspaceRoot = Directory(directory.absolute.path);
    final actualCanonical = _canonicalDirectoryPath(workspaceRoot);
    final expectedCanonical = canonicalWorkspaceRoot == null
        ? actualCanonical
        : p.normalize(p.absolute(canonicalWorkspaceRoot));
    if (!p.equals(actualCanonical, expectedCanonical)) {
      throw StateError('app_workspace_root_unsafe');
    }
    _workspaceRoot = workspaceRoot;
    _canonicalWorkspaceRoot = expectedCanonical;
    _accountWorkspace = accountWorkspace;
  }

  static bool get isAccountWorkspace => _accountWorkspace;

  /// 获取应用数据根目录；账号工作区会在业务存储初始化前完成绑定。
  static Future<Directory> getAppDataDirectory() async {
    return _workspaceRoot ?? await getInstallationRootDirectory();
  }

  /// 获取上传文件目录。
  static Future<Directory> getUploadDirectory() async {
    return _getManagedDirectory(const <String>['upload']);
  }

  /// 获取图片文件目录。
  static Future<Directory> getImagesDirectory() async {
    return _getManagedDirectory(const <String>['images']);
  }

  /// 获取头像文件目录。
  static Future<Directory> getAvatarsDirectory() async {
    return _getManagedDirectory(const <String>['avatars']);
  }

  /// 获取用户导入字体目录。
  static Future<Directory> getFontsDirectory() async {
    return _getManagedDirectory(const <String>['fonts']);
  }

  /// 获取工作区缓存目录。
  static Future<Directory> getCacheDirectory() async {
    return _getManagedDirectory(const <String>['cache']);
  }

  /// Gets the platform-provided application cache directory.
  ///
  /// - Android: /data/user/0/`<package>`/cache
  /// - iOS/macOS: Caches directory
  /// - Windows/Linux: platform cache directory (app-specific on Linux via XDG)
  static Future<Directory> getSystemCacheDirectory() async {
    if (_accountWorkspace) {
      return _getManagedDirectory(const <String>['cache', 'system']);
    }
    return await getApplicationCacheDirectory();
  }

  /// Gets the directory for avatar cache files.
  static Future<Directory> getAvatarCacheDirectory() async {
    return _getManagedDirectory(const <String>['cache', 'avatars']);
  }

  static Future<Directory> _getManagedDirectory(List<String> segments) async {
    final root = await getAppDataDirectory();
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    final rootType = await FileSystemEntity.type(root.path, followLinks: false);
    if (rootType != FileSystemEntityType.directory) {
      throw StateError('app_workspace_root_unsafe');
    }
    final actualRoot = _canonicalDirectoryPath(root);
    final expectedRoot = _canonicalWorkspaceRoot ?? actualRoot;
    if (!p.equals(actualRoot, expectedRoot)) {
      throw StateError('app_workspace_root_unsafe');
    }

    var directory = root;
    var expectedCanonical = expectedRoot;
    for (final segment in segments) {
      if (segment.isEmpty || p.basename(segment) != segment) {
        throw ArgumentError.value(segments, 'segments');
      }
      directory = Directory(p.join(directory.path, segment));
      expectedCanonical = p.join(expectedCanonical, segment);
      var type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) {
        await directory.create();
        type = await FileSystemEntity.type(directory.path, followLinks: false);
      }
      if (type != FileSystemEntityType.directory) {
        throw StateError('app_managed_directory_unsafe');
      }
      final actualCanonical = _canonicalDirectoryPath(directory);
      if (!p.equals(actualCanonical, p.normalize(expectedCanonical))) {
        throw StateError('app_managed_directory_unsafe');
      }
    }
    return directory;
  }

  static String _canonicalDirectoryPath(Directory directory) {
    try {
      return p.normalize(directory.resolveSymbolicLinksSync());
    } on FileSystemException catch (error) {
      // 部分 Windows 虚拟卷不提供规范路径 API；非账号工作区只有在
      // 逐级排除链接后才能使用绝对路径，账号隔离边界始终保持失败关闭。
      if (Platform.isWindows &&
          !_accountWorkspace &&
          error.osError?.errorCode == 1 &&
          _hasNoLinkComponent(directory.path)) {
        return p.normalize(p.absolute(directory.path));
      }
      rethrow;
    }
  }

  static bool _hasNoLinkComponent(String path) {
    try {
      var current = p.normalize(p.absolute(path));
      while (true) {
        final type = FileSystemEntity.typeSync(current, followLinks: false);
        if (type == FileSystemEntityType.notFound ||
            type == FileSystemEntityType.link) {
          return false;
        }
        final parent = p.dirname(current);
        if (p.equals(parent, current)) return true;
        current = parent;
      }
    } on FileSystemException {
      return false;
    }
  }

  /// Get file extension from MIME type
  static String extFromMime(String mime) {
    switch (mime.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      default:
        return 'png';
    }
  }

  /// Save base64 image data to images directory.
  /// [prefix] is used for filename (e.g. 'img', 'mcp_img').
  /// Returns the saved file path, or null if failed.
  static Future<String?> saveBase64Image(
    String mime,
    String base64Data, {
    String prefix = 'img',
  }) async {
    try {
      final dir = await getImagesDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final cleaned = base64Data.replaceAll(RegExp(r'\s'), '');
      List<int> bytes;
      // Support both standard base64 and URL-safe base64
      if (cleaned.contains('-') || cleaned.contains('_')) {
        bytes = base64Url.decode(cleaned);
      } else {
        bytes = base64Decode(cleaned);
      }
      final ext = extFromMime(mime);
      final path =
          '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      return path;
    } catch (e) {
      debugPrint('Failed to save image: $e');
      return null;
    }
  }
}
