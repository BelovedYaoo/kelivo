import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_settings_cold_ack.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

/// 在进程内测试中，将持久确认重新绑定到合成的原生进程。
///
/// 生产代码必须观察真实进程退出。测试无法替换 Dart VM，
/// 因此此辅助工具会显式模拟由不同 PID 写入的确认。
Future<void> simulateRestoreColdProcessBoundary(
  Directory appDataDirectory,
) async {
  final pending = await RestoreStartupGate.inspect(
    appDataDirectory: appDataDirectory,
  );
  if (pending == null) {
    throw StateError('restore_test_missing_pending_run');
  }
  final store = RestoreSettingsColdAckStore(
    runDirectory: Directory(
      p.join(
        appDataDirectory.path,
        RestoreWorkspaceLock.workspaceRootName,
        'run_${pending.runId}',
      ),
    ),
  );
  final ack = await store.read();
  if (ack == null) throw StateError('restore_test_missing_cold_ack');
  final otherProcessId = pid == 1 ? 2 : pid - 1;
  await store.writeOrReplace(
    terminalReceiptChecksum: ack.terminalReceiptChecksum,
    expected: ack.expected,
    leaseInstanceId: ack.leaseInstanceId,
    processId: otherProcessId,
  );
}
