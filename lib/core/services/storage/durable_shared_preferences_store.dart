import 'dart:convert';
import 'dart:io';

import 'package:kelivo_durable_preferences/kelivo_durable_preferences.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

abstract interface class DurableSharedPreferencesStore {
  Future<Set<String>> readRawKeys();

  Future<void> remove(String rawKey);
}

final class PlatformDurableSharedPreferencesStore
    implements DurableSharedPreferencesStore {
  const PlatformDurableSharedPreferencesStore(
    SharedPreferencesStorePlatform platform, {
    required DurableSharedPreferencesRemovalProof removalProof,
  }) : this._(platform, removalProof);

  const PlatformDurableSharedPreferencesStore._(
    this._platform,
    this._removalProof,
  );

  factory PlatformDurableSharedPreferencesStore.forCurrentPlatform() {
    final platform = SharedPreferencesStorePlatform.instance;
    final DurableSharedPreferencesRemovalProof removalProof;
    if (platform is KelivoDurablePreferences || Platform.isAndroid) {
      removalProof = const _NativeDurableMutationReceiptRemovalProof();
    } else if (Platform.isWindows || Platform.isLinux) {
      removalProof = ManagedRootSharedPreferencesRemovalProof(
        applicationSupportDirectory: getApplicationSupportDirectory,
      );
    } else {
      removalProof = const _UnsupportedSharedPreferencesRemovalProof();
    }
    return PlatformDurableSharedPreferencesStore(
      platform,
      removalProof: removalProof,
    );
  }

  final SharedPreferencesStorePlatform _platform;
  final DurableSharedPreferencesRemovalProof _removalProof;

  @override
  Future<Set<String>> readRawKeys() async {
    final values = await _platform.getAllWithParameters(
      GetAllParameters(filter: PreferencesFilter(prefix: '')),
    );
    return values.keys.toSet();
  }

  @override
  Future<void> remove(String rawKey) async {
    final session = await _removalProof.beginRemoval(rawKey);
    (Object, StackTrace)? operationFailure;
    try {
      if (!await _platform.remove(rawKey)) {
        throw StateError('durable_shared_preferences_remove_rejected');
      }
      await session.confirmRemoval();
      if ((await readRawKeys()).contains(rawKey)) {
        throw StateError('durable_shared_preferences_remove_incomplete');
      }
    } catch (error, stackTrace) {
      operationFailure = (error, stackTrace);
    }

    (Object, StackTrace)? closeFailure;
    try {
      await session.close();
    } catch (error, stackTrace) {
      closeFailure = (error, stackTrace);
    }

    if (operationFailure != null && closeFailure != null) {
      Error.throwWithStackTrace(
        _DurableSharedPreferencesRemovalFailure(
          operationFailure: operationFailure.$1,
          closeFailure: closeFailure.$1,
        ),
        operationFailure.$2,
      );
    }
    if (operationFailure != null) {
      Error.throwWithStackTrace(operationFailure.$1, operationFailure.$2);
    }
    if (closeFailure != null) {
      Error.throwWithStackTrace(closeFailure.$1, closeFailure.$2);
    }
  }
}

abstract interface class DurableSharedPreferencesRemovalProof {
  Future<DurableSharedPreferencesRemovalSession> beginRemoval(String rawKey);
}

abstract interface class DurableSharedPreferencesRemovalSession {
  Future<void> confirmRemoval();

  Future<void> close();
}

final class _NativeDurableMutationReceiptRemovalProof
    implements DurableSharedPreferencesRemovalProof {
  const _NativeDurableMutationReceiptRemovalProof();

  @override
  Future<DurableSharedPreferencesRemovalSession> beginRemoval(
    String rawKey,
  ) async => const _AndroidCommitReceiptRemovalSession();
}

final class _AndroidCommitReceiptRemovalSession
    implements DurableSharedPreferencesRemovalSession {
  const _AndroidCommitReceiptRemovalSession();

  @override
  Future<void> confirmRemoval() async {}

  @override
  Future<void> close() async {}
}

final class ManagedRootSharedPreferencesRemovalProof
    implements DurableSharedPreferencesRemovalProof {
  const ManagedRootSharedPreferencesRemovalProof({
    required Future<Directory> Function() applicationSupportDirectory,
    KelivoSecureCore secureCore = const KelivoSecureCore(),
  }) : this._(applicationSupportDirectory, secureCore);

  const ManagedRootSharedPreferencesRemovalProof._(
    this._applicationSupportDirectory,
    this._secureCore,
  );

  final Future<Directory> Function() _applicationSupportDirectory;
  final KelivoSecureCore _secureCore;

  static const _rawKeyMaxSize = 1024;

  @override
  Future<DurableSharedPreferencesRemovalSession> beginRemoval(
    String rawKey,
  ) async {
    // 必须在平台删除前匹配原生 ABI 边界，否则会留下无法再次证明的半完成状态。
    if (rawKey.isEmpty ||
        rawKey.contains('\u0000') ||
        utf8.encode(rawKey).length > _rawKeyMaxSize) {
      throw StateError('durable_shared_preferences_key_unsafe');
    }
    final directory = await _applicationSupportDirectory();
    final root = await _secureCore.openSharedPreferencesRoot(directory.path);
    return _ManagedRootSharedPreferencesRemovalSession(root, rawKey);
  }
}

final class _ManagedRootSharedPreferencesRemovalSession
    implements DurableSharedPreferencesRemovalSession {
  _ManagedRootSharedPreferencesRemovalSession(this._root, this._rawKey);

  final KelivoSharedPreferencesRootSession _root;
  final String _rawKey;

  @override
  Future<void> confirmRemoval() => _root.confirmRemoval(rawKey: _rawKey);

  @override
  Future<void> close() => _root.close();
}

final class _UnsupportedSharedPreferencesRemovalProof
    implements DurableSharedPreferencesRemovalProof {
  const _UnsupportedSharedPreferencesRemovalProof();

  @override
  Future<DurableSharedPreferencesRemovalSession> beginRemoval(String rawKey) {
    throw UnsupportedError('durable_shared_preferences_platform');
  }
}

final class _DurableSharedPreferencesRemovalFailure implements Exception {
  const _DurableSharedPreferencesRemovalFailure({
    required this.operationFailure,
    required this.closeFailure,
  });

  final Object operationFailure;
  final Object closeFailure;

  @override
  String toString() => 'durable_shared_preferences_operation_and_close_failed';
}
