import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/providers/cloud_sync_provider.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_recovery_production_runner.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_recovery_runner.dart';
import 'package:Kelivo/core/services/workspace/account_session_token_store.dart';
import 'package:Kelivo/core/services/workspace/account_workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

E2eeAccountRecoveryRunnerFactory _recoveryRunnerFactory(
  AccountWorkspaceRuntime workspaceRuntime,
) {
  return ({required accountClient, required authentication}) {
    if (accountClient is! E2eeAccountRecoveryClient) {
      throw StateError('账户恢复生产依赖不完整');
    }
    if (authentication is! E2eeAccountRecoveryAuthentication) {
      throw StateError('账户恢复生产依赖不完整');
    }
    return E2eeAccountRecoveryProductionRunner(
      client: accountClient,
      authentication: authentication as E2eeAccountRecoveryAuthentication,
      workspaceRuntime: workspaceRuntime,
      deviceStateStore: DeviceStateBlobStore(
        installationRoot: workspaceRuntime.installationRoot,
      ),
    );
  };
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('账户注册保存介质后清除数据可恢复', (tester) async {
    final installRoot = await AppDirectories.getInstallationRootDirectory();
    final testRoot = Directory(p.join(installRoot.path, 'kelivo-recovery-e2e'));
    if (await testRoot.exists()) {
      await testRoot.delete(recursive: true);
    }
    await testRoot.create(recursive: true);
    final loginName = 'e2eint${DateTime.now().millisecondsSinceEpoch % 100000}';
    final password = Uint8List.fromList('TestPass2026'.codeUnits);
    final recoveryPassphrase = Uint8List.fromList('Recovery0806A'.codeUnits);

    // 设备 A：注册并导出恢复介质。
    final rootA = Directory(p.join(testRoot.path, 'deviceA'));
    final workspaceA = await AccountWorkspaceRuntime.bootstrap(
      installationRoot: rootA,
      sessionTokenStore: const SecureAccountSessionTokenStore(),
    );
    final providerA = CloudSyncProvider.controlPlaneOnly(
      workspaceA,
      accountRecoveryRunnerFactory: _recoveryRunnerFactory(workspaceA),
    );
    Uint8List? recoveryMedia;
    final registered = await providerA.register(
      loginName: loginName,
      displayName: 'E2E Int',
      password: 'TestPass2026',
      recoveryPassphrase: 'Recovery0806A',
      deviceName: 'E2E Device A',
      encryptedMediaExporter: (media) async {
        recoveryMedia = Uint8List.fromList(media);
        return true;
      },
    );
    expect(registered, isTrue, reason: '注册应成功');
    expect(recoveryMedia, isNotNull, reason: '应导出恢复介质');
    providerA.dispose();
    await workspaceA.close();

    // 设备 B（全新安装根）：使用介质恢复。
    final rootB = Directory(p.join(testRoot.path, 'deviceB'));
    final workspaceB = await AccountWorkspaceRuntime.bootstrap(
      installationRoot: rootB,
      sessionTokenStore: const SecureAccountSessionTokenStore(),
    );
    final providerB = CloudSyncProvider.controlPlaneOnly(
      workspaceB,
      accountRecoveryRunnerFactory: _recoveryRunnerFactory(workspaceB),
    );
    final command = E2eeAccountRecoveryCommand(
      loginName: loginName,
      deviceName: 'E2E Device B',
      accountPassword: Uint8List.fromList(password),
      recoveryPassphrase: Uint8List.fromList(recoveryPassphrase),
      encryptedRecoveryMedia: recoveryMedia!,
    );
    final recovered = await providerB.startAccountRecovery(command);
    expect(
      recovered,
      isFalse,
      reason: '恢复需切换工作区，应返回重启请求: ${providerB.lastError}',
    );
    expect(providerB.workspaceRestartRequired, isTrue);
    expect(providerB.lastError, isNull);
    providerB.dispose();
    await workspaceB.close();

    // 重启后：重新打开同一安装根，恢复的会话应可用。
    final workspaceB2 = await AccountWorkspaceRuntime.bootstrap(
      installationRoot: rootB,
      sessionTokenStore: const SecureAccountSessionTokenStore(),
    );
    final providerB2 = CloudSyncProvider.controlPlaneOnly(
      workspaceB2,
      accountRecoveryRunnerFactory: _recoveryRunnerFactory(workspaceB2),
    );
    await providerB2.initialize();
    expect(providerB2.signedIn, isTrue, reason: '重启后应已恢复会话');
    providerB2.dispose();
    await workspaceB2.close();

    await testRoot.delete(recursive: true);
  });
}
