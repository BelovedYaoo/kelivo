import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../backup/restore_business_lease.dart';
import '../backup/restore_durability.dart';
import 'local_wipe_marker_topology.dart';

enum InstallationOperationLeasePlatform {
  windows,
  android,
  linux,
  apple,
  unsupported,
}

typedef InstallationBusinessOwnerPublishHook = Future<void> Function();

final class InstallationBusinessLeaseUnavailable implements Exception {
  const InstallationBusinessLeaseUnavailable(this.path, {this.cause});

  final String path;
  final Object? cause;

  @override
  String toString() => 'Installation business lease unavailable: $path';
}

/// 协调安装级业务 I/O 与不可逆的本机密码学擦除。
///
/// sidecar 有意位于安装目录之外，避免擦除安装目录时删除仍在持有的锁。
final class InstallationOperationLease {
  InstallationOperationLease({
    required Directory installationRoot,
    RestoreDurability? durability,
  }) : this._(
         installationRoot: installationRoot,
         durability: durability ?? RestorePlatformDurability(),
         platform: _currentPlatform(),
         beforeBusinessOwnerPublish: null,
       );

  InstallationOperationLease.forTesting({
    required Directory installationRoot,
    required InstallationOperationLeasePlatform platform,
    RestoreDurability? durability,
    InstallationBusinessOwnerPublishHook? beforeBusinessOwnerPublish,
  }) : this._(
         installationRoot: installationRoot,
         durability: durability ?? RestorePlatformDurability(),
         platform: platform,
         beforeBusinessOwnerPublish: beforeBusinessOwnerPublish,
       );

  InstallationOperationLease._({
    required Directory installationRoot,
    required this._durability,
    required this._platform,
    required this._beforeBusinessOwnerPublish,
  }) : _installationRoot = Directory(
         p.normalize(p.absolute(installationRoot.path)),
       ) {
    final rootPath = _installationRoot.path;
    final parentPath = p.dirname(rootPath);
    final rootName = p.basename(rootPath);
    _sidecarDirectory = Directory(
      p.join(parentPath, '.$rootName.kelivo-installation-operation-lease'),
    );
  }

  static const _activityDirectoryName = 'activity';
  static const _activeLockFileName = 'active.lock';
  static const _ownerPrefix = 'owner_';
  static const _ownerFormat = 'kelivo.installation-business-owner';
  static const _ownerVersion = 1;
  static const _maximumOwnerBytes = 4096;
  static const _pollInterval = Duration(milliseconds: 25);
  static final RegExp _ownerNamePattern = RegExp(
    r'^owner_([0-9]+)_([0-9a-f]{32})\.json$',
  );

  final Directory _installationRoot;
  final RestoreDurability _durability;
  final InstallationOperationLeasePlatform _platform;
  final InstallationBusinessOwnerPublishHook? _beforeBusinessOwnerPublish;
  late final Directory _sidecarDirectory;
  InstallationWipeLease? _retainedWipeLease;
  InstallationWipeIntent? _retainedWipeIntent;

  Directory get sidecarDirectory => _sidecarDirectory;

  Directory get _activityDirectory =>
      Directory(p.join(_sidecarDirectory.path, _activityDirectoryName));

  File get _activeLockFile =>
      File(p.join(_activityDirectory.path, _activeLockFileName));

  Future<InstallationBusinessLease> acquireBusiness() async {
    if (_platform == InstallationOperationLeasePlatform.apple) {
      await _requireSafeInstallationRoot();
      final snapshot = await LocalWipeMarkerTopology.inspect(_installationRoot);
      if (!snapshot.isEmpty) {
        throw UnsupportedError('installation_operation_lease_apple_pending');
      }
      return InstallationBusinessLease._noop();
    }
    _requireSupportedPlatform();
    await _requireSafeLayout(createSidecar: true);
    late final RestoreBusinessLease turnstile;
    try {
      turnstile = await RestoreBusinessLease.acquire(
        appDataDirectory: _sidecarDirectory,
        durability: _durability,
      );
    } on RestoreBusinessLeaseUnavailable catch (error) {
      throw InstallationBusinessLeaseUnavailable(
        _sidecarDirectory.path,
        cause: error,
      );
    }

    RandomAccessFile? activeHandle;
    _InstallationBusinessOwnerProbe? ownerProbe;
    File? ownerFile;
    var activeLocked = false;
    try {
      await _requireSafeLayout(createSidecar: false);
      if (await _hasPendingWipeArtifacts()) {
        throw InstallationBusinessLeaseUnavailable(_installationRoot.path);
      }
      await _requireActivityDirectory();
      activeHandle = await _openActiveLock();
      try {
        await activeHandle.lock(FileLock.shared);
        activeLocked = true;
      } on FileSystemException catch (error) {
        if (_isLockUnavailable(error)) {
          throw InstallationBusinessLeaseUnavailable(
            _activeLockFile.path,
            cause: error,
          );
        }
        rethrow;
      }

      await _beforeBusinessOwnerPublish?.call();
      final token = _newToken();
      ownerProbe = await _InstallationBusinessOwnerProbe.open(token);
      ownerFile = await _publishOwner(token: token, probe: ownerProbe);
      await turnstile.close();
      return InstallationBusinessLease._(
        activeHandle: activeHandle,
        ownerFile: ownerFile,
        ownerProbe: ownerProbe,
      );
    } catch (error, stackTrace) {
      Object? cleanupError;
      StackTrace? cleanupStackTrace;
      Future<void> clean(Future<void> Function() action) async {
        try {
          await action();
        } catch (nextError, nextStackTrace) {
          cleanupError ??= nextError;
          cleanupStackTrace ??= nextStackTrace;
        }
      }

      if (activeHandle != null) {
        if (activeLocked) {
          await clean(activeHandle.unlock);
        }
        await clean(activeHandle.close);
      }
      if (ownerProbe != null) await clean(ownerProbe.close);
      if (ownerFile != null) {
        await clean(() => _deleteOwner(ownerFile!));
      }
      await clean(turnstile.close);
      if (cleanupError != null &&
          error is InstallationBusinessLeaseUnavailable) {
        Error.throwWithStackTrace(cleanupError!, cleanupStackTrace!);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<InstallationWipeLease> _prepareWipe({
    required bool allowNoArtifactRelease,
  }) async {
    final retained = _retainedWipeLease;
    if (retained != null) {
      if (!allowNoArtifactRelease) retained._forbidNoArtifactRelease();
      return retained;
    }
    _requireSupportedPlatform();
    await _requireSafeLayout(createSidecar: true);
    final turnstile = await _acquireWipeTurnstile();
    final lease = InstallationWipeLease._(
      coordinator: this,
      turnstile: turnstile,
      allowNoArtifactRelease: allowNoArtifactRelease,
    );
    _retainedWipeLease = lease;
    return lease;
  }

  /// 在 requested 落盘前持有 turnstile，消除 marker 发布与新业务获取竞态。
  ///
  /// 调用方必须依次耐久发布 requested、关闭本进程 business lease、等待
  /// [InstallationWipeIntent.drainBusinessAfterRequestedPublished]，再发网络请求。
  Future<InstallationWipeIntent> beginRevocationRequest() async {
    if (_platform == InstallationOperationLeasePlatform.apple) {
      throw UnsupportedError('installation_operation_lease_apple');
    }
    final existing = _retainedWipeIntent;
    if (existing != null) return existing;
    final lease = await _prepareWipe(allowNoArtifactRelease: false);
    if (await _hasPendingWipeArtifacts()) {
      throw StateError('installation_wipe_intent_artifact_exists');
    }
    final intent = InstallationWipeIntent._(lease);
    _retainedWipeIntent = intent;
    return intent;
  }

  /// cold-start 在任何 workspace bootstrap 前调用，返回时已经持有 exclusive。
  ///
  /// 任一失败都会在当前 coordinator 内保留 turnstile，后续调用复用同一
  /// lease；只有确认不存在任何 marker/temp 时才会返回 null 并释放。
  Future<InstallationWipeLease?> acquirePendingWipe() async {
    if (_platform == InstallationOperationLeasePlatform.apple) {
      await _requireSafeInstallationRoot();
      final snapshot = await LocalWipeMarkerTopology.inspect(_installationRoot);
      if (snapshot.isEmpty) return null;
      throw UnsupportedError('installation_operation_lease_apple_pending');
    }
    final lease = await _prepareWipe(allowNoArtifactRelease: true);
    if (!await _hasPendingWipeArtifacts()) {
      await lease._cancelBeforeMarker();
      return null;
    }
    await lease._confirmPendingArtifacts();
    await lease._waitForBusinessQuiescence();
    return lease;
  }

  void _forgetWipeLease(InstallationWipeLease lease) {
    if (identical(_retainedWipeLease, lease)) {
      _retainedWipeLease = null;
      _retainedWipeIntent = null;
    }
  }

  Future<RestoreBusinessLease> _acquireWipeTurnstile() async {
    while (true) {
      try {
        return await RestoreBusinessLease.acquire(
          appDataDirectory: _sidecarDirectory,
          durability: _durability,
        );
      } on RestoreBusinessLeaseUnavailable {
        await Future<void>.delayed(_pollInterval);
      }
    }
  }

  Future<bool> _hasPendingWipeArtifacts() async {
    await _requireSafeLayout(createSidecar: false);
    return !(await LocalWipeMarkerTopology.inspect(_installationRoot)).isEmpty;
  }

  Future<void> _requireSafeInstallationRoot() async {
    final rootPath = _installationRoot.path;
    final parent = _installationRoot.parent;
    if (p.equals(rootPath, parent.path) ||
        p.equals(parent.path, parent.parent.path) ||
        p.basename(rootPath).isEmpty ||
        !p.equals(p.dirname(_sidecarDirectory.path), parent.path) ||
        p.basename(_sidecarDirectory.path) !=
            '.${p.basename(rootPath)}.kelivo-installation-operation-lease') {
      throw StateError('installation_operation_lease_path_unsafe');
    }
    await _requireCanonicalDirectory(
      parent,
      'installation_operation_lease_parent_unsafe',
    );
    await _requireCanonicalDirectory(
      _installationRoot,
      'installation_operation_lease_root_unsafe',
    );
  }

  Future<void> _requireSafeLayout({required bool createSidecar}) async {
    await _requireSafeInstallationRoot();

    final sidecarType = await FileSystemEntity.type(
      _sidecarDirectory.path,
      followLinks: false,
    );
    if (sidecarType == FileSystemEntityType.notFound && createSidecar) {
      await _sidecarDirectory.create();
      await _durability.restrictDirectory(_sidecarDirectory);
    } else if (sidecarType != FileSystemEntityType.directory) {
      throw StateError('installation_operation_lease_sidecar_unsafe');
    }
    await _requireCanonicalDirectory(
      _sidecarDirectory,
      'installation_operation_lease_sidecar_unsafe',
    );
    await _durability.restrictDirectory(_sidecarDirectory);
  }

  Future<void> _requireCanonicalDirectory(
    Directory directory,
    String errorCode,
  ) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError(errorCode);
    }
    final canonical = p.normalize(
      p.absolute(await directory.resolveSymbolicLinks()),
    );
    if (!p.equals(canonical, p.normalize(p.absolute(directory.path)))) {
      throw StateError(errorCode);
    }
  }

  Future<void> _requireActivityDirectory() async {
    final activity = _activityDirectory;
    final type = await FileSystemEntity.type(activity.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await activity.create();
      await _durability.restrictDirectory(activity);
    } else if (type != FileSystemEntityType.directory) {
      throw StateError('installation_operation_lease_activity_unsafe');
    }
    await _requireCanonicalDirectory(
      activity,
      'installation_operation_lease_activity_unsafe',
    );
    if (!p.equals(activity.parent.path, _sidecarDirectory.path)) {
      throw StateError('installation_operation_lease_activity_unsafe');
    }
    await _durability.restrictDirectory(activity);
  }

  Future<RandomAccessFile> _openActiveLock() async {
    final lockFile = _activeLockFile;
    final initialType = await FileSystemEntity.type(
      lockFile.path,
      followLinks: false,
    );
    if (initialType != FileSystemEntityType.notFound &&
        initialType != FileSystemEntityType.file) {
      throw StateError('installation_operation_lease_active_lock_unsafe');
    }
    final handle = await lockFile.open(mode: FileMode.append);
    if (await FileSystemEntity.type(lockFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      await handle.close();
      throw StateError('installation_operation_lease_active_lock_unsafe');
    }
    await _durability.restrictFile(lockFile);
    return handle;
  }

  Future<File> _publishOwner({
    required String token,
    required _InstallationBusinessOwnerProbe probe,
  }) async {
    final owner = File(
      p.join(_activityDirectory.path, '$_ownerPrefix${pid}_$token.json'),
    );
    await owner.create(exclusive: true);
    try {
      await _durability.restrictFile(owner);
      final identity = jsonEncode({
        'format': _ownerFormat,
        'version': _ownerVersion,
        'processId': pid,
        'token': token,
        'probePort': probe.port,
      });
      if (utf8.encode(identity).length > _maximumOwnerBytes) {
        throw StateError('installation_operation_lease_owner_size');
      }
      await owner.writeAsString(identity, flush: true);
      if (await FileSystemEntity.type(owner.path, followLinks: false) !=
              FileSystemEntityType.file ||
          await owner.readAsString() != identity) {
        throw StateError('installation_operation_lease_owner_identity');
      }
      return owner;
    } catch (_) {
      await _deleteOwner(owner);
      rethrow;
    }
  }

  Future<bool> _hasLiveBusinessOwners() async {
    var hasLiveOwner = false;
    await for (final entity in _activityDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      // business 关闭允许在目录枚举后、类型检查前原子删除自己的 owner。
      if (type == FileSystemEntityType.notFound) continue;
      if (name == _activeLockFileName) {
        if (type != FileSystemEntityType.file) {
          throw StateError('installation_operation_lease_active_lock_unsafe');
        }
        continue;
      }
      final match = _ownerNamePattern.firstMatch(name);
      if (match == null || type != FileSystemEntityType.file) {
        throw StateError('installation_operation_lease_activity_entry_unsafe');
      }
      late final _InstallationBusinessOwner owner;
      try {
        owner = await _readOwner(File(entity.path), match);
      } on FileSystemException {
        if (await FileSystemEntity.type(entity.path, followLinks: false) ==
            FileSystemEntityType.notFound) {
          continue;
        }
        rethrow;
      }
      if (owner.processId == pid) {
        // 同进程 POSIX 锁可能被升级；只有持有者显式删除 owner 才能证明退出。
        hasLiveOwner = true;
        continue;
      }
      if (await _InstallationBusinessOwnerProbe.isLive(owner)) {
        hasLiveOwner = true;
      } else {
        await _deleteOwner(File(entity.path));
      }
    }
    return hasLiveOwner;
  }

  Future<_InstallationBusinessOwner> _readOwner(
    File file,
    RegExpMatch fileNameMatch,
  ) async {
    final length = await file.length();
    if (length <= 0 || length > _maximumOwnerBytes) {
      throw StateError('installation_operation_lease_owner_identity');
    }
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?> ||
        decoded['format'] != _ownerFormat ||
        decoded['version'] != _ownerVersion ||
        decoded['processId'] is! int ||
        decoded['token'] is! String ||
        decoded['probePort'] is! int) {
      throw StateError('installation_operation_lease_owner_identity');
    }
    final owner = _InstallationBusinessOwner(
      processId: decoded['processId'] as int,
      token: decoded['token'] as String,
      probePort: decoded['probePort'] as int,
    );
    if (owner.processId <= 0 ||
        owner.processId.toString() != fileNameMatch.group(1) ||
        owner.token != fileNameMatch.group(2) ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(owner.token) ||
        owner.probePort <= 0 ||
        owner.probePort > 65535) {
      throw StateError('installation_operation_lease_owner_identity');
    }
    return owner;
  }

  Future<void> _deleteOwner(File owner) async {
    await _deleteInstallationOwnerFile(owner);
  }

  void _requireSupportedPlatform() {
    switch (_platform) {
      case InstallationOperationLeasePlatform.windows:
      case InstallationOperationLeasePlatform.android:
      case InstallationOperationLeasePlatform.linux:
        return;
      case InstallationOperationLeasePlatform.apple:
        throw UnsupportedError('installation_operation_lease_apple');
      case InstallationOperationLeasePlatform.unsupported:
        throw UnsupportedError('installation_operation_lease_platform');
    }
  }

  static InstallationOperationLeasePlatform _currentPlatform() {
    if (Platform.isWindows) return InstallationOperationLeasePlatform.windows;
    if (Platform.isAndroid) return InstallationOperationLeasePlatform.android;
    if (Platform.isLinux) return InstallationOperationLeasePlatform.linux;
    if (Platform.isIOS || Platform.isMacOS) {
      return InstallationOperationLeasePlatform.apple;
    }
    return InstallationOperationLeasePlatform.unsupported;
  }

  static String _newToken() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}

final class InstallationBusinessLease {
  InstallationBusinessLease._({
    required this._activeHandle,
    required this._ownerFile,
    required this._ownerProbe,
  });

  InstallationBusinessLease._noop()
    : _activeHandle = null,
      _ownerFile = null,
      _ownerProbe = null {
    _activeUnlocked = true;
    _activeClosed = true;
    _ownerProbeClosed = true;
    _ownerDeleted = true;
  }

  RandomAccessFile? _activeHandle;
  final File? _ownerFile;
  final _InstallationBusinessOwnerProbe? _ownerProbe;
  Future<void>? _closing;
  bool _activeUnlocked = false;
  bool _activeClosed = false;
  bool _ownerProbeClosed = false;
  bool _ownerDeleted = false;

  bool get isClosed => _activeClosed && _ownerProbeClosed && _ownerDeleted;

  Future<void> close() {
    if (isClosed) return Future<void>.value();
    final existing = _closing;
    if (existing != null) return existing;
    late final Future<void> closing;
    closing = _closeSteps().whenComplete(() {
      if (identical(_closing, closing)) _closing = null;
    });
    _closing = closing;
    return closing;
  }

  Future<void> _closeSteps() async {
    final handle = _activeHandle;
    Object? firstError;
    StackTrace? firstStackTrace;
    Future<void> closeStep(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (!_activeUnlocked && handle != null) {
      await closeStep(() async {
        await handle.unlock();
        _activeUnlocked = true;
      });
    }
    if (!_activeClosed && handle != null) {
      await closeStep(() async {
        await handle.close();
        _activeClosed = true;
        _activeUnlocked = true;
        _activeHandle = null;
      });
    }
    final ownerProbe = _ownerProbe;
    if (!_ownerProbeClosed && ownerProbe != null) {
      await closeStep(() async {
        await ownerProbe.close();
        _ownerProbeClosed = true;
      });
    }
    final ownerFile = _ownerFile;
    if (!_ownerDeleted && ownerFile != null) {
      await closeStep(() async {
        await _deleteInstallationOwnerFile(ownerFile);
        _ownerDeleted = true;
      });
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }
}

final class InstallationWipeLease {
  InstallationWipeLease._({
    required this._coordinator,
    required this._turnstile,
    required this._allowNoArtifactRelease,
  });

  final InstallationOperationLease _coordinator;
  RestoreBusinessLease? _turnstile;
  RandomAccessFile? _exclusiveHandle;
  Future<void>? _exclusiveAcquisition;
  Future<void>? _completion;
  bool _markerConfirmed = false;
  bool _exclusiveAcquired = false;
  bool _exclusiveUnlocked = false;
  bool _exclusiveClosed = false;
  bool _turnstileClosed = false;
  bool _allowNoArtifactRelease;

  bool get isExclusive => _exclusiveAcquired && !_exclusiveClosed;
  bool get isClosed => _exclusiveClosed && _turnstileClosed;

  void _forbidNoArtifactRelease() {
    _allowNoArtifactRelease = false;
  }

  Future<void> _confirmPendingArtifacts() async {
    if (isClosed) throw StateError('installation_wipe_lease_closed');
    if (_markerConfirmed) return;
    if (!await _coordinator._hasPendingWipeArtifacts()) {
      throw StateError('installation_wipe_lease_marker_missing');
    }
    _markerConfirmed = true;
  }

  Future<void> _waitForBusinessQuiescence() {
    if (!_markerConfirmed) {
      return Future<void>.error(
        StateError('installation_wipe_lease_marker_unconfirmed'),
      );
    }
    if (isClosed) {
      return Future<void>.error(StateError('installation_wipe_lease_closed'));
    }
    if (_exclusiveAcquired) return Future<void>.value();
    final existing = _exclusiveAcquisition;
    if (existing != null) return existing;
    final acquisition = _acquireExclusive();
    _exclusiveAcquisition = acquisition;
    return acquisition.whenComplete(() {
      if (_exclusiveHandle == null &&
          identical(_exclusiveAcquisition, acquisition)) {
        _exclusiveAcquisition = null;
      }
    });
  }

  Future<void> _acquireExclusive() async {
    await _coordinator._requireSafeLayout(createSidecar: false);
    await _coordinator._requireActivityDirectory();
    final handle = await _coordinator._openActiveLock();
    try {
      while (true) {
        if (!await _coordinator._hasPendingWipeArtifacts()) {
          throw StateError('installation_wipe_lease_marker_missing');
        }
        if (await _coordinator._hasLiveBusinessOwners()) {
          await Future<void>.delayed(InstallationOperationLease._pollInterval);
          continue;
        }
        try {
          await handle.lock(FileLock.exclusive);
        } on FileSystemException catch (error) {
          if (!_isLockUnavailable(error)) rethrow;
          await Future<void>.delayed(InstallationOperationLease._pollInterval);
          continue;
        }
        if (await _coordinator._hasLiveBusinessOwners()) {
          await handle.unlock();
          await Future<void>.delayed(InstallationOperationLease._pollInterval);
          continue;
        }
        _exclusiveHandle = handle;
        _exclusiveAcquired = true;
        return;
      }
    } catch (_) {
      await handle.close();
      rethrow;
    }
  }

  Future<void> _cancelBeforeMarker() async {
    final turnstile = _turnstile;
    if (turnstile == null) return;
    if (!_allowNoArtifactRelease ||
        _markerConfirmed ||
        _exclusiveHandle != null) {
      throw StateError('installation_wipe_lease_cancel_forbidden');
    }
    if (await _coordinator._hasPendingWipeArtifacts()) {
      throw StateError('installation_wipe_lease_marker_pending');
    }
    await turnstile.close();
    _turnstile = null;
    _exclusiveUnlocked = true;
    _exclusiveClosed = true;
    _turnstileClosed = true;
    _coordinator._forgetWipeLease(this);
  }

  /// 仅在擦除状态机已经耐久删除所有 marker/temp 后释放。
  Future<void> complete() {
    if (isClosed) {
      _coordinator._forgetWipeLease(this);
      return Future<void>.value();
    }
    final existing = _completion;
    if (existing != null) return existing;
    late final Future<void> completion;
    completion = _completeSteps().whenComplete(() {
      if (identical(_completion, completion)) _completion = null;
    });
    _completion = completion;
    return completion;
  }

  Future<void> _completeSteps() async {
    final handle = _exclusiveHandle;
    final turnstile = _turnstile;
    if (!_exclusiveAcquired ||
        (!_exclusiveClosed && handle == null) ||
        (!_turnstileClosed && turnstile == null)) {
      throw StateError('installation_wipe_lease_not_exclusive');
    }
    if (await _coordinator._hasPendingWipeArtifacts()) {
      throw StateError('installation_wipe_lease_marker_pending');
    }

    Object? firstError;
    StackTrace? firstStackTrace;
    Future<void> closeStep(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (!_exclusiveUnlocked && handle != null) {
      await closeStep(() async {
        await handle.unlock();
        _exclusiveUnlocked = true;
      });
    }
    if (!_exclusiveClosed && handle != null) {
      await closeStep(() async {
        await handle.close();
        _exclusiveClosed = true;
        _exclusiveUnlocked = true;
        _exclusiveHandle = null;
      });
    }
    if (!_turnstileClosed && turnstile != null) {
      await closeStep(() async {
        await turnstile.close();
        _turnstileClosed = true;
        _turnstile = null;
      });
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
    if (!isClosed) {
      throw StateError('installation_wipe_lease_close_incomplete');
    }
    _coordinator._forgetWipeLease(this);
  }
}

/// 远端撤销请求的本机排空凭证；不提供释放方法。
final class InstallationWipeIntent {
  InstallationWipeIntent._(this._lease);

  final InstallationWipeLease _lease;

  bool get isExclusive => _lease.isExclusive;

  /// requested 必须已经耐久发布，且调用方必须先关闭本进程 business lease。
  ///
  /// 返回后 turnstile 与 exclusive 都继续持有；网络未知、confirmed 落盘失败
  /// 或其他异常均不得释放，只能由进程退出交给 cold-start 恢复。
  Future<void> drainBusinessAfterRequestedPublished() async {
    await _lease._confirmPendingArtifacts();
    await _lease._waitForBusinessQuiescence();
  }
}

final class _InstallationBusinessOwner {
  const _InstallationBusinessOwner({
    required this.processId,
    required this.token,
    required this.probePort,
  });

  final int processId;
  final String token;
  final int probePort;
}

final class _InstallationBusinessOwnerProbe {
  _InstallationBusinessOwnerProbe._(this._server, this._token);

  static const _timeout = Duration(milliseconds: 300);

  final ServerSocket _server;
  final String _token;

  int get port => _server.port;

  static Future<_InstallationBusinessOwnerProbe> open(String token) async {
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    final probe = _InstallationBusinessOwnerProbe._(server, token);
    server.listen(probe._answer, onError: (_) {});
    return probe;
  }

  static Future<bool> isLive(_InstallationBusinessOwner owner) async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        owner.probePort,
        timeout: _timeout,
      );
      try {
        socket.writeln(owner.token);
        await socket.flush();
        final response = await socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(_timeout);
        return response == 'alive';
      } finally {
        socket.destroy();
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _answer(Socket socket) async {
    try {
      final request = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(_timeout);
      socket.writeln(request == _token ? 'alive' : 'denied');
      await socket.flush();
    } catch (_) {
      // 非法探针不改变 owner 的权威状态。
    } finally {
      await socket.close();
    }
  }

  Future<void> close() => _server.close();
}

bool _isLockUnavailable(FileSystemException error) {
  final code = error.osError?.errorCode;
  if (code == null) return false;
  if (Platform.isWindows) return code == 32 || code == 33;
  return code == 11 || code == 13 || code == 35;
}

Future<void> _deleteInstallationOwnerFile(File owner) async {
  for (var attempt = 0; ; attempt++) {
    final type = await FileSystemEntity.type(owner.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('installation_operation_lease_owner_unsafe');
    }
    try {
      await owner.delete();
      return;
    } on FileSystemException catch (error) {
      // Windows 可能在 writer 枚举 owner 的短窗口返回 sharing violation。
      // 只重试该明确错误，其他权限或路径异常仍立即失败关闭。
      final code = error.osError?.errorCode;
      if (!Platform.isWindows || (code != 32 && code != 33) || attempt >= 80) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
}
