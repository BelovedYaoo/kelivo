import 'dart:io';

import 'package:Kelivo/core/services/workspace/account_workspace_runtime.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 系统应用沙箱别名可完成工作区启动', (tester) async {
    expect(Platform.isAndroid, isTrue);
    final installationRoot =
        await AppDirectories.getInstallationRootDirectory();
    final workspaceRoot = Directory(
      '${installationRoot.path}${Platform.pathSeparator}.kelivo-workspaces',
    );
    if (await workspaceRoot.exists()) {
      await workspaceRoot.delete(recursive: true);
    }

    final runtime = await AccountWorkspaceRuntime.bootstrap(
      installationRoot: installationRoot,
    );
    try {
      expect(runtime.current.isLocal, isTrue);
      expect(await runtime.current.dataDirectory.exists(), isTrue);
      expect(
        p.normalize(runtime.installationRoot.path),
        p.normalize(await installationRoot.resolveSymbolicLinks()),
      );
    } finally {
      await runtime.close();
      if (await workspaceRoot.exists()) {
        await workspaceRoot.delete(recursive: true);
      }
    }
  });

  testWidgets('Android 应用可写链接不得越过安装根边界', (tester) async {
    expect(Platform.isAndroid, isTrue);
    final caseRoot = await Directory.systemTemp.createTemp(
      'kelivo-workspace-link-',
    );
    final externalRoot = await Directory.systemTemp.createTemp(
      'kelivo-workspace-external-',
    );
    final externalInstallationRoot = Directory(
      p.join(externalRoot.path, 'kelivo'),
    );
    final link = Link(p.join(caseRoot.path, 'redirected-parent'));
    final sentinel = File(p.join(externalRoot.path, 'sentinel'));
    await externalInstallationRoot.create(recursive: true);
    await sentinel.writeAsString('external', flush: true);
    await link.create(externalRoot.path);

    Future<void> bootstrapAndClose() async {
      final runtime = await AccountWorkspaceRuntime.bootstrap(
        installationRoot: Directory(p.join(link.path, 'kelivo')),
      );
      await runtime.close();
    }

    try {
      await expectLater(
        bootstrapAndClose(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'account_workspace_installation_root_unsafe',
          ),
        ),
      );
      expect(await sentinel.readAsString(), 'external');
      expect(
        await Directory(
          p.join(externalInstallationRoot.path, '.kelivo-workspaces'),
        ).exists(),
        isFalse,
      );
    } finally {
      if (await link.exists()) await link.delete();
      if (await caseRoot.exists()) await caseRoot.delete(recursive: true);
      if (await externalRoot.exists()) {
        await externalRoot.delete(recursive: true);
      }
    }
  });

  testWidgets('Android 系统沙箱 bind 别名可执行受管根固定操作', (tester) async {
    expect(Platform.isAndroid, isTrue);
    final currentInstallationRoot =
        await AppDirectories.getInstallationRootDirectory();
    final canonicalInstallationRoot = p.normalize(
      await currentInstallationRoot.resolveSymbolicLinks(),
    );
    expect(canonicalInstallationRoot.startsWith('/data/data/'), isTrue);
    final installationRoot = Directory(
      '/data/user/0/${canonicalInstallationRoot.substring('/data/data/'.length)}',
    );
    expect(
      p.normalize(installationRoot.path).startsWith('/data/user/0/'),
      isTrue,
    );
    expect(
      p.normalize(await installationRoot.resolveSymbolicLinks()),
      canonicalInstallationRoot,
    );
    final caseRoot = Directory(
      p.join(installationRoot.path, 'managed-root-alias-test'),
    );
    if (await caseRoot.exists()) {
      await caseRoot.delete(recursive: true);
    }
    await caseRoot.create();

    KelivoInstallationRootSession? session;
    try {
      final staging = Directory(
        p.join(caseRoot.path, 'upload', 'e2ee', 'staging'),
      );
      await staging.create(recursive: true);
      await File(
        p.join(staging.path, 'plaintext.part'),
      ).writeAsString('secret', flush: true);
      session = await const KelivoSecureCore().openInstallationRoot(
        caseRoot.path,
      );

      await session.retireAttachmentStaging();

      expect(await staging.exists(), isFalse);
      expect(await caseRoot.exists(), isTrue);
    } finally {
      await session?.close();
      if (await caseRoot.exists()) {
        await caseRoot.delete(recursive: true);
      }
    }
  });
}
