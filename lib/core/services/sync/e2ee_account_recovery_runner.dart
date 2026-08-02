import 'dart:typed_data';

import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_recovery.dart';
import 'e2ee_first_device_registration_commit_coordinator.dart';
import 'sensitive_utf8.dart';

const e2eeAccountRecoveryUnsupportedCode = 'SYNC_ACCOUNT_RECOVERY_UNSUPPORTED';
const e2eeAccountRecoveryMediaInvalidCode =
    'AUTH_ACCOUNT_RECOVERY_MEDIA_INVALID';
const e2eeAccountRecoveryDeviceAlreadyAuthenticatedCode =
    'SYNC_ACCOUNT_RECOVERY_DEVICE_ALREADY_AUTHENTICATED';
const e2eeAccountRecoveryAuthGenerationInvalidCode =
    'SYNC_ACCOUNT_RECOVERY_AUTH_GENERATION_INVALID';

abstract interface class E2eeAccountRecoveryAuthentication {
  /// 为避免密码在调用方继续驻留，所有退出路径都会清零传入缓冲区。
  Future<E2eeAccountRecoveryOnboardingLease> begin({
    required String loginName,
    required Uint8List password,
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
  });

  Future<E2eeAccountRecoveryReopenLease> reopenRecovery({
    required String loginName,
    required E2eeAccountRecoveryCheckpoint checkpoint,
  });

  Future<void> close();
}

abstract interface class E2eeAccountRecoveryOnboardingLease {
  CloudSyncOnboardingToken get onboardingToken;

  DateTime get onboardingTokenExpiresAt;

  String get loginName;

  String get deviceId;

  String get deviceName;

  CloudSyncPlatform get platform;

  String get clientVersion;

  int get deviceKeyVersion;

  int get sourceAuthGeneration;

  int get targetAuthGeneration;

  DeviceStateBlobVersion get sourceStateVersion;

  /// 返回由调用方拥有的独立副本；调用方用毕后必须主动清零。
  Uint8List copySourceStateBlob();

  E2eeAccountRecoveryProofCore get proofCore;

  bool get isClosed;

  Future<void> close();
}

abstract interface class E2eeAccountRecoveryReopenLease {
  E2eeAccountRecoveryReopenBinding get binding;

  E2eeAccountRecoveryProofCore get proofCore;

  /// 必须在恢复工作区变更租约内调用，避免验证后的跨进程状态变更。
  Future<void> requireCurrentState();

  bool get isClosed;

  Future<void> close();
}

enum E2eeAccountRecoveryProgress {
  authenticating,
  verifyingRecoveryMedia,
  rebuildingTrustedDevice,
  restoringEncryptedData,
  completing,
  completed,
  failed,
}

typedef E2eeAccountRecoveryProgressCallback =
    void Function(E2eeAccountRecoveryProgress progress);

final class E2eeAccountRecoveryInput {
  const E2eeAccountRecoveryInput._({
    required this.loginName,
    required this.deviceName,
    required this.accountPassword,
    required this.recoveryPassphrase,
    required this.encryptedRecoveryMedia,
  });

  final String loginName;
  final String deviceName;
  final Uint8List accountPassword;
  final Uint8List recoveryPassphrase;
  final Uint8List encryptedRecoveryMedia;

  @override
  String toString() => 'E2eeAccountRecoveryInput(<敏感材料已隐藏>)';
}

final class E2eeAccountRecoveryCommand {
  factory E2eeAccountRecoveryCommand({
    required String loginName,
    required String deviceName,
    required Uint8List accountPassword,
    required Uint8List recoveryPassphrase,
    required Uint8List encryptedRecoveryMedia,
  }) {
    Uint8List? ownedPassword;
    Uint8List? ownedRecoveryPassphrase;
    Uint8List? ownedRecoveryMedia;
    var created = false;
    try {
      final normalizedLoginName = loginName.trim();
      final normalizedDeviceName = deviceName.trim();
      if (normalizedLoginName.isEmpty || normalizedDeviceName.isEmpty) {
        throw const FormatException('账户恢复账号或设备名称为空');
      }
      if (accountPassword.isEmpty || recoveryPassphrase.isEmpty) {
        throw const FormatException('账户恢复凭据为空');
      }
      if (_sameBytes(accountPassword, recoveryPassphrase)) {
        throw const CloudSyncException(
          kind: CloudSyncFailureKind.validation,
          retryable: false,
          serverCode: e2eeRecoveryPassphraseMatchesPasswordCode,
        );
      }
      if (encryptedRecoveryMedia.length != e2eeEncryptedRecoveryMediaBytes) {
        throw const CloudSyncException(
          kind: CloudSyncFailureKind.validation,
          retryable: false,
          serverCode: e2eeAccountRecoveryMediaInvalidCode,
        );
      }
      ownedPassword = Uint8List.fromList(accountPassword);
      ownedRecoveryPassphrase = Uint8List.fromList(recoveryPassphrase);
      ownedRecoveryMedia = Uint8List.fromList(encryptedRecoveryMedia);
      final command = E2eeAccountRecoveryCommand._(
        normalizedLoginName,
        normalizedDeviceName,
        ownedPassword,
        ownedRecoveryPassphrase,
        ownedRecoveryMedia,
      );
      created = true;
      return command;
    } finally {
      clearSensitiveBytes(accountPassword);
      clearSensitiveBytes(recoveryPassphrase);
      clearSensitiveBytes(encryptedRecoveryMedia);
      if (!created) {
        clearSensitiveBytes(ownedPassword);
        clearSensitiveBytes(ownedRecoveryPassphrase);
        clearSensitiveBytes(ownedRecoveryMedia);
      }
    }
  }

  E2eeAccountRecoveryCommand._(
    this._loginName,
    this._deviceName,
    this._accountPassword,
    this._recoveryPassphrase,
    this._encryptedRecoveryMedia,
  );

  final String _loginName;
  final String _deviceName;
  Uint8List? _accountPassword;
  Uint8List? _recoveryPassphrase;
  Uint8List? _encryptedRecoveryMedia;
  bool _consumed = false;

  Future<T> use<T>(Future<T> Function(E2eeAccountRecoveryInput input) action) {
    if (_consumed) {
      throw StateError('账户恢复命令已被消费');
    }
    _consumed = true;
    final password = _accountPassword;
    final passphrase = _recoveryPassphrase;
    final media = _encryptedRecoveryMedia;
    if (password == null || passphrase == null || media == null) {
      throw StateError('账户恢复命令缺少提交材料');
    }
    return _useAndClear(
      E2eeAccountRecoveryInput._(
        loginName: _loginName,
        deviceName: _deviceName,
        accountPassword: password,
        recoveryPassphrase: passphrase,
        encryptedRecoveryMedia: media,
      ),
      action,
    );
  }

  Future<T> _useAndClear<T>(
    E2eeAccountRecoveryInput input,
    Future<T> Function(E2eeAccountRecoveryInput input) action,
  ) async {
    try {
      return await action(input);
    } finally {
      dispose();
    }
  }

  void dispose() {
    clearSensitiveBytes(_accountPassword);
    clearSensitiveBytes(_recoveryPassphrase);
    clearSensitiveBytes(_encryptedRecoveryMedia);
    _accountPassword = null;
    _recoveryPassphrase = null;
    _encryptedRecoveryMedia = null;
  }

  @override
  String toString() => 'E2eeAccountRecoveryCommand(<敏感材料已隐藏>)';
}

abstract interface class E2eeAccountRecoveryRunner {
  Future<CloudSyncAuthenticatedSession> recover({
    required E2eeAccountRecoveryInput input,
    required CloudSyncPlatform platform,
    required String clientVersion,
    required E2eeAccountRecoveryProgressCallback onProgress,
  });

  Future<void> acknowledgeWorkspaceBound();

  Future<void> close();
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
