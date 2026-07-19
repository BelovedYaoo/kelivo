import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'
    show ErrorDescription, FlutterError, FlutterErrorDetails, debugPrint;
import 'package:path/path.dart' as p;
import './app_directories.dart';

/// Resolves persisted absolute file paths that include the iOS sandbox UUID
/// to the current app container path after an app update.
///
/// Example:
///   Before update: /var/mobile/Containers/Data/Application/ABC/Documents/upload/x.png
///   After update:  /var/mobile/Containers/Data/Application/XYZ/Documents/upload/x.png
///
/// We store absolute paths in message content. On iOS, the container prefix
/// changes after update. This helper rewrites any path that points into our
/// previous container's Documents subfolders (upload/avatars) to the current
/// Documents directory. If the rewritten file exists, it returns the new path;
/// otherwise returns the original path.
class SandboxPathResolver {
  SandboxPathResolver._();

  static String? _docsDir;
  static String? _supportDir;
  static String? _installationRoot;
  static bool _accountWorkspace = false;
  static bool debug = false;

  /// Call once during app startup to cache the current Documents directory.
  static Future<void> init() async {
    _accountWorkspace = AppDirectories.isAccountWorkspace;
    // 使用平台对应的应用数据目录，确保后续路径判断与真实存储根一致。
    final dir = await AppDirectories.getAppDataDirectory();
    _docsDir = dir.path;
    _installationRoot =
        (await AppDirectories.getInstallationRootDirectory()).path;
    try {
      if (_accountWorkspace) {
        _supportDir = null;
      } else {
        final sup = await getApplicationSupportDirectory();
        _supportDir = sup.path;
      }
    } catch (error, stackTrace) {
      _supportDir = null;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'sandbox_path_resolver',
          context: ErrorDescription('读取兼容路径根目录失败'),
        ),
      );
    }
    if (debug) {
      debugPrint(
        '[SandboxPathResolver.init] docsDir=$_docsDir supportDir=$_supportDir',
      );
    }
  }

  /// Synchronously map an old absolute path to the current container's path
  /// when it points under our managed subfolders (upload/images/avatars).
  /// If mapping succeeds and the target exists, returns the mapped path;
  /// otherwise returns [path] unchanged.
  static String fix(String path) {
    if (path.isEmpty) return path;

    // Strip file:// scheme if present
    final String raw0 = path.startsWith('file://') ? path.substring(7) : path;
    // Normalize backslashes to forward slashes for matching
    final String raw = raw0.replaceAll('\\', '/');

    final docs = _docsDir;
    final support = _supportDir;
    if (docs == null || docs.isEmpty) {
      if (_accountWorkspace || AppDirectories.isAccountWorkspace) {
        throw StateError('sandbox_path_resolver_not_initialized');
      }
      return raw;
    }
    final installationRoot = _installationRoot;
    final accountsRoot = installationRoot == null
        ? null
        : p.join(installationRoot, '.kelivo-workspaces', 'accounts');
    final forbiddenDocsRoot = _accountWorkspace ? null : accountsRoot;
    final isAccountTreePath =
        accountsRoot != null && _isSameOrWithin(accountsRoot, raw0);
    final isCurrentWorkspaceDataPath =
        _isSameOrWithin(docs, raw0) &&
        (_accountWorkspace || !isAccountTreePath);
    final blocksPersistedPath = !isCurrentWorkspaceDataPath;

    // Determine root and tail to map
    // Cases we support:
    // - iOS/macOS: .../Documents/<subdir>/...
    // - Android: .../app_flutter/<subdir>/... or .../files/<subdir>/...
    // - Windows: .../AppData/Local/Kelivo/<subdir>/... or .../Kelivo/<subdir>/...
    const subdirs = ['avatars', 'fonts', 'images', 'upload'];
    String? tail; // starts with '/'
    String rootType = 'unknown';

    final int iosIdx = raw.indexOf('/Documents/');
    if (iosIdx != -1) {
      final candidateTail = raw.substring(
        iosIdx + '/Documents'.length,
      ); // includes leading '/'
      // Check subdir presence to avoid false positives
      if (subdirs.any((s) => candidateTail.startsWith('/$s/'))) {
        tail = candidateTail;
        rootType = 'documents';
      }
    }

    // Try to match Windows AppData paths (exported from Windows, imported elsewhere)
    if (tail == null) {
      final int kelivoIdx = raw.indexOf('/kelivo/');
      if (kelivoIdx != -1) {
        final candidateTail = raw.substring(
          kelivoIdx + '/kelivo'.length,
        ); // includes leading '/'
        if (subdirs.any((s) => candidateTail.startsWith('/$s/'))) {
          tail = candidateTail;
          rootType = 'windows_kelivo';
        }
      }
    }

    if (tail == null) {
      for (final androidRoot in const ['/app_flutter/', '/files/']) {
        final int aidx = raw.indexOf(androidRoot);
        if (aidx != -1) {
          final after = raw.substring(aidx + androidRoot.length);
          if (subdirs.any((s) => after.startsWith('$s/'))) {
            tail = '/$after';
            rootType = androidRoot.replaceAll('/', '');
            break;
          }
        }
      }
    }

    // Final generic fallback: detect '/avatars/' '/images/' '/upload/' anywhere in the path
    if (tail == null) {
      for (final s in subdirs) {
        final i = raw.indexOf('/$s/');
        if (i != -1) {
          tail = raw.substring(i); // includes leading '/'
          rootType = 'generic_subdir';
          break;
        }
      }
    }

    if (tail == null) {
      if (blocksPersistedPath) {
        return _blockedPath(docs, raw);
      }
      final validated = _validatedWorkspaceCandidate(
        root: docs,
        candidate: raw0,
        forbiddenRoot: forbiddenDocsRoot,
      );
      if (validated == null) return _blockedPath(docs, raw);
      if (debug) {
        debugPrint(
          '[SandboxPathResolver.fix] input=$path -> skipped (no known subdir pattern found)',
        );
      }
      return raw;
    }

    // 先收敛父目录段，越界候选不能进入任何文件系统探测。
    final mappedOutput = '$docs$tail';
    final mapped = _validatedWorkspaceCandidate(
      root: docs,
      candidate: mappedOutput,
      forbiddenRoot: forbiddenDocsRoot,
    );
    if (mapped == null) return _blockedPath(docs, raw);
    try {
      if (File(mapped).existsSync()) {
        if (debug) {
          debugPrint(
            '[SandboxPathResolver.fix] root=$rootType input=$path -> mappedDocs=$mapped (exists)',
          );
        }
        return mappedOutput;
      } else {
        if (debug) {
          debugPrint(
            '[SandboxPathResolver.fix] root=$rootType tried mappedDocs=$mapped (missing)',
          );
        }
      }
    } catch (e) {
      if (debug) {
        debugPrint(
          '[SandboxPathResolver.fix] root=$rootType mappedDocs error: $e',
        );
      }
    }

    // Secondary: try ApplicationSupportDirectory
    if (support != null && support.isNotEmpty) {
      final altOutput = '$support$tail';
      final alt = _validatedWorkspaceCandidate(
        root: support,
        candidate: altOutput,
      );
      if (alt == null) return _blockedPath(docs, raw);
      try {
        if (File(alt).existsSync()) {
          if (debug) {
            debugPrint(
              '[SandboxPathResolver.fix] root=$rootType input=$path -> mappedSupport=$alt (exists)',
            );
          }
          return altOutput;
        } else {
          if (debug) {
            debugPrint(
              '[SandboxPathResolver.fix] root=$rootType tried mappedSupport=$alt (missing)',
            );
          }
        }
      } catch (e) {
        if (debug) {
          debugPrint(
            '[SandboxPathResolver.fix] root=$rootType mappedSupport error: $e',
          );
        }
      }
    }

    // 持久路径只能在当前工作区内重映射；找不到目标时也返回当前根下的
    // 不存在路径，避免账号与匿名工作区通过绝对路径互相读取附件。
    if (blocksPersistedPath) return mappedOutput;

    // Fallback: search by basename under common folders in both roots
    final String base = _basename(tail);
    for (final root in <String?>[docs, support]) {
      if (root == null || root.isEmpty) continue;
      for (final sub in const ['avatars', 'fonts', 'images', 'upload']) {
        final probeOutput = '$root/$sub/$base';
        final probe = _validatedWorkspaceCandidate(
          root: root,
          candidate: probeOutput,
          forbiddenRoot: p.equals(root, docs) ? forbiddenDocsRoot : null,
        );
        if (probe == null) continue;
        try {
          if (File(probe).existsSync()) {
            if (debug) {
              debugPrint(
                '[SandboxPathResolver.fix] root=$rootType input=$path -> basenameProbe=$probe (exists)',
              );
            }
            return probeOutput;
          } else {
            if (debug) {
              debugPrint(
                '[SandboxPathResolver.fix] root=$rootType tried basenameProbe=$probe (missing)',
              );
            }
          }
        } catch (e) {
          if (debug) {
            debugPrint(
              '[SandboxPathResolver.fix] root=$rootType basenameProbe error: $e',
            );
          }
        }
      }
    }
    if (debug) {
      debugPrint(
        '[SandboxPathResolver.fix] root=$rootType input=$path -> unchanged=$raw (no match)',
      );
    }
    final validated = _validatedWorkspaceCandidate(
      root: docs,
      candidate: raw0,
      forbiddenRoot: forbiddenDocsRoot,
    );
    return validated == null ? _blockedPath(docs, raw) : raw;
  }

  /// 仅用于用户刚刚显式选中的源文件；调用方必须立即复制到当前工作区，
  /// 不得把返回值写入配置、数据库或同步载荷。
  static String resolveUserSelectedSource(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('file://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.scheme == 'file') {
        return p.normalize(uri.toFilePath(windows: Platform.isWindows));
      }
    }
    return p.normalize(p.absolute(trimmed));
  }

  /// 仅当路径在指定受管目录内且规范路径未通过链接越界时返回 true。
  /// 删除本地资源前必须使用精确归属判断，不能把其他账号的路径重映射到当前工作区。
  static bool isOwnedManagedPath({
    required String path,
    required Directory managedDirectory,
  }) {
    final raw = path.trim();
    if (raw.isEmpty) return false;
    if ((_accountWorkspace || AppDirectories.isAccountWorkspace) &&
        (_docsDir == null || _docsDir!.isEmpty)) {
      return false;
    }
    try {
      var candidate = raw;
      if (raw.startsWith('file://')) {
        final uri = Uri.tryParse(raw);
        if (uri == null || uri.scheme != 'file') return false;
        candidate = uri.toFilePath(windows: Platform.isWindows);
      }
      final docs = _docsDir;
      if (docs == null || docs.isEmpty) return false;
      final normalizedDocs = p.normalize(p.absolute(docs));
      final root = p.normalize(p.absolute(managedDirectory.path));
      if (!p.isWithin(normalizedDocs, root)) return false;
      final normalizedCandidate = p.normalize(p.absolute(candidate));
      if (!p.isWithin(root, normalizedCandidate)) return false;
      final canonicalDocs = _canonicalExistingPath(normalizedDocs);
      final canonicalRoot = _canonicalExistingPath(root);
      if (canonicalDocs == null || canonicalRoot == null) {
        return false;
      }
      final expectedRoot = p.normalize(
        p.join(canonicalDocs, p.relative(root, from: normalizedDocs)),
      );
      if (!p.equals(canonicalRoot, expectedRoot)) return false;
      var nearestExisting = normalizedCandidate;
      while (FileSystemEntity.typeSync(nearestExisting, followLinks: false) ==
          FileSystemEntityType.notFound) {
        final parent = p.dirname(nearestExisting);
        if (p.equals(parent, nearestExisting) ||
            !(_isSameOrWithin(root, parent))) {
          return false;
        }
        nearestExisting = parent;
      }
      final canonicalCandidate = _canonicalExistingPath(nearestExisting);
      if (canonicalCandidate == null) return false;
      final expectedCandidate = p.normalize(
        p.join(canonicalRoot, p.relative(nearestExisting, from: root)),
      );
      return p.equals(canonicalCandidate, expectedCandidate);
    } on ArgumentError {
      return false;
    }
  }

  /// 仅用于比较两个现存文件是否指向同一规范文件。
  /// 调用方在执行删除前仍必须单独校验目标文件的受管目录归属。
  static String? canonicalExistingPathForComparison(String path) {
    final raw = path.trim();
    if (raw.isEmpty) return null;
    return _canonicalExistingPath(raw);
  }

  static String _basename(String p) {
    if (p.isEmpty) return p;
    final norm = p.replaceAll('\\', '/');
    final i = norm.lastIndexOf('/');
    return i == -1 ? norm : norm.substring(i + 1);
  }

  static String _blockedPath(String workspaceRoot, String rawPath) {
    final candidate = p.join(
      workspaceRoot,
      '.blocked-account-workspace',
      _basename(rawPath),
    );
    final installationRoot = _installationRoot;
    final forbiddenRoot = !_accountWorkspace && installationRoot != null
        ? p.join(installationRoot, '.kelivo-workspaces', 'accounts')
        : null;
    final validated = _validatedWorkspaceCandidate(
      root: workspaceRoot,
      candidate: candidate,
      forbiddenRoot: forbiddenRoot,
    );
    if (validated == null || File(validated).existsSync()) {
      return p.normalize(p.absolute(workspaceRoot));
    }
    return validated;
  }

  static String? _validatedWorkspaceCandidate({
    required String root,
    required String candidate,
    String? forbiddenRoot,
  }) {
    try {
      final normalizedRoot = p.normalize(p.absolute(root));
      final normalizedCandidate = p.normalize(p.absolute(candidate));
      if (!_isSameOrWithin(normalizedRoot, normalizedCandidate)) return null;
      if (forbiddenRoot != null &&
          _isSameOrWithin(forbiddenRoot, normalizedCandidate)) {
        return null;
      }

      final canonicalRoot = _canonicalExistingPath(normalizedRoot);
      final canonicalCandidate = _canonicalNearestExistingPath(
        normalizedCandidate,
      );
      if (canonicalRoot == null ||
          canonicalCandidate == null ||
          !_isSameOrWithin(canonicalRoot, canonicalCandidate)) {
        return null;
      }

      if (forbiddenRoot != null) {
        final canonicalForbidden = _canonicalExistingPath(forbiddenRoot);
        if (canonicalForbidden != null &&
            _isSameOrWithin(canonicalForbidden, canonicalCandidate)) {
          return null;
        }
      }
      return normalizedCandidate;
    } on ArgumentError {
      return null;
    }
  }

  static String? _canonicalNearestExistingPath(String candidate) {
    var current = candidate;
    while (true) {
      final type = FileSystemEntity.typeSync(current, followLinks: false);
      if (type != FileSystemEntityType.notFound) {
        return _canonicalExistingPath(current);
      }
      final parent = p.dirname(current);
      if (p.equals(parent, current)) return null;
      current = parent;
    }
  }

  static String? _canonicalExistingPath(String path) {
    try {
      final normalized = p.normalize(p.absolute(path));
      final type = FileSystemEntity.typeSync(normalized, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        return p.normalize(Directory(normalized).resolveSymbolicLinksSync());
      }
      if (type == FileSystemEntityType.file) {
        return p.normalize(File(normalized).resolveSymbolicLinksSync());
      }
      if (type == FileSystemEntityType.link) {
        return p.normalize(Link(normalized).resolveSymbolicLinksSync());
      }
      return null;
    } on FileSystemException catch (error) {
      // 部分 Windows 虚拟卷不支持 canonical API；只有逐级确认不存在
      // reparse point 后才能退回规范化路径，避免为兼容性放开链接越界。
      if (Platform.isWindows &&
          !(_accountWorkspace || AppDirectories.isAccountWorkspace) &&
          error.osError?.errorCode == 1 &&
          _hasNoLinkComponent(path)) {
        return p.normalize(p.absolute(path));
      }
      return null;
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

  static bool _isSameOrWithin(String root, String candidate) {
    try {
      final normalizedRoot = p.normalize(p.absolute(root));
      final normalizedCandidate = p.normalize(p.absolute(candidate));
      return p.equals(normalizedRoot, normalizedCandidate) ||
          p.isWithin(normalizedRoot, normalizedCandidate);
    } on ArgumentError {
      return false;
    }
  }

  // Expose current dirs for diagnostic purposes
  static String? get docsDir => _docsDir;
  static String? get supportDir => _supportDir;
}
