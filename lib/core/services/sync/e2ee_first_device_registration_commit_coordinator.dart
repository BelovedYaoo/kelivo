import 'dart:typed_data';

const e2eeEncryptedRecoveryMediaBytes = 644;

typedef E2eeEncryptedRecoveryMediaExporter =
    Future<bool> Function(Uint8List encryptedMedia);

enum E2eeRecoveryMediaCommitStage { awaitingExport, exportConfirmed }

final class E2eeRecoveryMediaExportCancelled implements Exception {
  const E2eeRecoveryMediaExportCancelled();
}

final class E2eeFirstDeviceRegistrationCommitCoordinator {
  const E2eeFirstDeviceRegistrationCommitCoordinator();

  Future<T> start<T>({
    required Future<void> Function() persistAwaitingExport,
    required Future<bool> Function() exportRecoveryMedia,
    required Future<void> Function() persistExportConfirmed,
    required Future<void> Function() installAccountState,
    required Future<T> Function() submitRegistration,
  }) async {
    // 介质只能在可恢复的本地事务存在后离开进程边界。
    await persistAwaitingExport();
    return resume<T>(
      stage: E2eeRecoveryMediaCommitStage.awaitingExport,
      exportRecoveryMedia: exportRecoveryMedia,
      persistExportConfirmed: persistExportConfirmed,
      installAccountState: installAccountState,
      submitRegistration: submitRegistration,
    );
  }

  Future<T> resume<T>({
    required E2eeRecoveryMediaCommitStage stage,
    required Future<bool> Function() exportRecoveryMedia,
    required Future<void> Function() persistExportConfirmed,
    required Future<void> Function() installAccountState,
    required Future<T> Function() submitRegistration,
  }) async {
    switch (stage) {
      case E2eeRecoveryMediaCommitStage.awaitingExport:
        if (!await exportRecoveryMedia()) {
          throw const E2eeRecoveryMediaExportCancelled();
        }
        // 确认状态是网络提交门禁，崩溃后不得靠内存中的布尔值越过。
        await persistExportConfirmed();
      case E2eeRecoveryMediaCommitStage.exportConfirmed:
        break;
    }
    await installAccountState();
    return submitRegistration();
  }
}
