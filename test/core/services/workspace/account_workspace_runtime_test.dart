import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/models/provider_group.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_coordinator.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_store.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/core/services/sync/sync_write_journal.dart';
import 'package:Kelivo/core/services/workspace/account_session_token_store.dart';
import 'package:Kelivo/core/services/workspace/account_workspace_runtime.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory installationRoot;
  late _MemoryAccountSessionTokenStore sessionTokenStore;
  final runtimes = <AccountWorkspaceRuntime>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    sessionTokenStore = _MemoryAccountSessionTokenStore();
    installationRoot = Directory(
      p.join(
        Directory.current.path,
        '.dart_tool',
        'account_workspace_tests',
        const Uuid().v4(),
      ),
    );
    await installationRoot.create(recursive: true);
  });

  tearDown(() async {
    for (final runtime in runtimes.reversed) {
      await runtime.close();
    }
    if (await installationRoot.exists()) {
      await installationRoot.delete(recursive: true);
    }
    SharedPreferences.resetStatic();
  });

  Future<AccountWorkspaceRuntime> bootstrap() async {
    final runtime = await AccountWorkspaceRuntime.bootstrap(
      installationRoot: installationRoot,
      sessionTokenStore: sessionTokenStore,
    );
    runtimes.add(runtime);
    return runtime;
  }

  Future<void> close(AccountWorkspaceRuntime runtime) async {
    await runtime.close();
    runtimes.remove(runtime);
  }

  test('账号工作区磁盘不得持久化 bearer token 明文', () async {
    const token = 'disk-sentinel-bearer-token';
    final runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: token));

    final tokenBytes = utf8.encode(token);
    final files = await installationRoot
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => !file.path.contains('.kelivo_business_lease'))
        .toList();
    expect(files, isNotEmpty);
    for (final file in files) {
      expect(
        _containsBytes(await file.readAsBytes(), tokenBytes),
        isFalse,
        reason: file.path,
      );
    }

    final sessionFiles = files
        .where((file) => p.basename(file.path).startsWith('session-v2-'))
        .toList();
    expect(sessionFiles, hasLength(1));
    final sessionRecord =
        jsonDecode(await sessionFiles.single.readAsString())
            as Map<String, Object?>;
    final payload = sessionRecord['payload'] as Map<String, Object?>;
    final sessionMetadata = payload['session'] as Map<String, Object?>;
    expect(payload.keys, <String>{
      'version',
      'accountScope',
      'session',
      'tokenReference',
    });
    expect(sessionMetadata, isNot(contains('token')));
    expect(payload['tokenReference'], <String, Object?>{
      'version': 1,
      'generation': 1,
      'slot': 'a',
    });
  });

  test('旧版明文会话启动时硬切并清除凭证', () async {
    const legacyToken = 'legacy-plaintext-token-sentinel';
    var runtime = await bootstrap();
    final session = _session(userId: 'account-a', token: legacyToken);
    await runtime.bindAccount(session);
    await close(runtime);

    final workspaceKey = sha256
        .convert(utf8.encode(session.accountScope))
        .toString();
    final accountDirectory = Directory(
      p.join(
        installationRoot.path,
        '.kelivo-workspaces',
        'accounts',
        workspaceKey,
      ),
    );
    for (final slot in const <String>['a', 'b']) {
      final current = File(
        p.join(accountDirectory.path, 'session-v2-$slot.json'),
      );
      if (await current.exists()) await current.delete();
    }
    final legacy = File(p.join(accountDirectory.path, 'session-v1-a.json'));
    await legacy.writeAsString(
      jsonEncode(<String, Object?>{
        'generation': 1,
        'payload': <String, Object?>{
          'version': 1,
          'accountScope': session.accountScope,
          'session': session.toJson(),
        },
      }),
      flush: true,
    );

    runtime = await bootstrap();
    expect(runtime.current.isLocal, isTrue);
    expect(sessionTokenStore.tokenCount, 0);
    expect(await legacy.exists(), isFalse);
    final persistedFiles = await installationRoot
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => !file.path.contains('.kelivo_business_lease'))
        .toList();
    for (final file in persistedFiles) {
      expect(
        _containsBytes(await file.readAsBytes(), utf8.encode(legacyToken)),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('会话令牌密文缺失时启动失败关闭', () async {
    final runtime = await bootstrap();
    await runtime.bindAccount(
      _session(userId: 'account-a', token: 'missing-token'),
    );
    await close(runtime);
    sessionTokenStore.clear();

    await expectLater(bootstrap(), throwsA(isA<StateError>()));
  });

  test('匿名工作区保留既有根目录且账号 A/B 的路径与配置前缀互不重叠', () async {
    var runtime = await bootstrap();
    expect(runtime.current.isLocal, isTrue);
    expect(runtime.current.dataDirectory.path, installationRoot.path);
    expect(runtime.current.preferencesPrefix, 'flutter.');

    final accountA = _session(userId: 'account-a', token: 'token-a');
    final accountB = _session(userId: 'account-b', token: 'token-b');
    final bindA = await runtime.bindAccount(accountA);
    expect(bindA, isA<AccountWorkspaceRestartRequired>());
    final targetA = (bindA as AccountWorkspaceRestartRequired).target;
    expect(runtime.current.isLocal, isTrue);
    expect(targetA.isLocal, isFalse);
    expect(targetA.dataDirectory.path, isNot(installationRoot.path));
    expect(targetA.preferencesPrefix, startsWith('kelivo.account.'));

    await close(runtime);
    runtime = await bootstrap();
    expect(runtime.current.session?.userId, 'account-a');
    expect(runtime.current.dataDirectory.path, targetA.dataDirectory.path);

    final bindB = await runtime.bindAccount(accountB);
    expect(bindB, isA<AccountWorkspaceRestartRequired>());
    final targetB = (bindB as AccountWorkspaceRestartRequired).target;
    expect(runtime.current.session?.userId, 'account-a');
    expect(targetB.dataDirectory.path, isNot(targetA.dataDirectory.path));
    expect(targetB.preferencesPrefix, isNot(targetA.preferencesPrefix));

    await close(runtime);
    runtime = await bootstrap();
    expect(runtime.current.session?.userId, 'account-b');
    expect(runtime.current.dataDirectory.path, targetB.dataDirectory.path);
  });

  test('切换到账号 B 后真实上传批次不包含账号 A 的本地配置', () async {
    var runtime = await bootstrap();
    final accountA = _session(userId: 'account-a', token: 'token-a');
    final accountB = _session(userId: 'account-b', token: 'token-b');
    await runtime.bindAccount(accountA);
    await close(runtime);

    runtime = await bootstrap();
    expect(runtime.current.session?.userId, accountA.userId);
    final accountASettings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await accountASettings.ready;
    await accountASettings.setProviderConfig(
      'account-a-provider',
      ProviderConfig.defaultsFor('account-a-provider'),
    );
    final accountAUpload = await _captureAccountProviderUpload(
      workspace: runtime.current,
      settings: accountASettings,
    );
    expect(
      accountAUpload.map((mutation) => mutation.entityId),
      contains('account-a-provider'),
    );

    final switchResult = await runtime.bindAccount(accountB);
    expect(switchResult, isA<AccountWorkspaceRestartRequired>());
    accountASettings.dispose();
    await close(runtime);
    SharedPreferences.resetStatic();

    runtime = await bootstrap();
    expect(runtime.current.session?.userId, accountB.userId);
    final accountBSettings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await accountBSettings.ready;
    expect(
      accountBSettings.providerConfigs,
      isNot(contains('account-a-provider')),
    );
    await accountBSettings.setProviderConfig(
      'account-b-provider',
      ProviderConfig.defaultsFor('account-b-provider'),
    );
    final accountBUpload = await _captureAccountProviderUpload(
      workspace: runtime.current,
      settings: accountBSettings,
    );
    final accountBUploadedIds = accountBUpload
        .map((mutation) => mutation.entityId)
        .toSet();

    expect(accountBUploadedIds, contains('account-b-provider'));
    expect(accountBUploadedIds, isNot(contains('account-a-provider')));
    accountBSettings.dispose();
  });

  test('同账号重新认证只更新会话而不切换工作区', () async {
    var runtime = await bootstrap();
    final original = _session(userId: 'account-a', token: 'old-token');
    await runtime.bindAccount(original);
    await close(runtime);

    runtime = await bootstrap();
    final originalPath = runtime.current.dataDirectory.path;
    final refreshed = _session(userId: 'account-a', token: 'new-token');
    final result = await runtime.bindAccount(refreshed);

    expect(result, isA<AccountWorkspaceRetained>());
    expect(runtime.current.dataDirectory.path, originalPath);
    expect(runtime.current.session?.token, 'new-token');

    await close(runtime);
    runtime = await bootstrap();
    expect(runtime.current.dataDirectory.path, originalPath);
    expect(runtime.current.session?.token, 'new-token');
  });

  test('账号目录祖先链接不能把账号数据重定向到其他位置', () async {
    final runtime = await bootstrap();
    final redirectedAccounts = Directory(
      p.join(installationRoot.path, 'redirected-accounts'),
    );
    await redirectedAccounts.create(recursive: true);
    final accountsPath = p.join(
      installationRoot.path,
      '.kelivo-workspaces',
      'accounts',
    );
    await _createDirectoryLink(accountsPath, redirectedAccounts.path);

    await expectLater(
      runtime.bindAccount(_session(userId: 'account-a', token: 'token-a')),
      throwsA(isA<StateError>()),
    );
    expect(await redirectedAccounts.list().toList(), isEmpty);
  });

  test('账号哈希目录链接不能复用另一个账号的数据目录', () async {
    final runtime = await bootstrap();
    final accountB = _session(userId: 'account-b', token: 'token-b');
    final bindB = await runtime.bindAccount(accountB);
    final accountBDirectory =
        (bindB as AccountWorkspaceRestartRequired).target.dataDirectory.parent;

    final accountA = _session(userId: 'account-a', token: 'token-a');
    final accountAKey = sha256
        .convert(utf8.encode(accountA.accountScope))
        .toString();
    final accountAPath = p.join(
      installationRoot.path,
      '.kelivo-workspaces',
      'accounts',
      accountAKey,
    );
    await _createDirectoryLink(accountAPath, accountBDirectory.path);

    await expectLater(
      runtime.bindAccount(accountA),
      throwsA(isA<StateError>()),
    );
    expect(runtime.current.isLocal, isTrue);
  });

  test('启动后安装根目录不随账号数据根切换', () async {
    var runtime = await bootstrap();
    expect(
      p.normalize((await AppDirectories.getInstallationRootDirectory()).path),
      p.normalize(installationRoot.path),
    );
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    runtime = await bootstrap();
    expect(AppDirectories.isAccountWorkspace, isTrue);
    expect(
      p.normalize((await AppDirectories.getInstallationRootDirectory()).path),
      p.normalize(installationRoot.path),
    );
    expect(
      p.normalize((await AppDirectories.getAppDataDirectory()).path),
      p.normalize(runtime.current.dataDirectory.path),
    );
  });

  test('显式重启交接释放安装级工作区租约', () async {
    final runtime = await bootstrap();

    await runtime.prepareRestartHandoff();
    final successor = await AccountWorkspaceRuntime.bootstrap(
      installationRoot: installationRoot,
      sessionTokenStore: sessionTokenStore,
    );
    runtimes.add(successor);

    expect(successor.current.isLocal, isTrue);
  });

  test('退出只切回匿名工作区并保留账号目录', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    runtime = await bootstrap();
    final accountDirectory = runtime.current.dataDirectory;
    final marker = File(p.join(accountDirectory.path, 'keep-me'));
    await marker.writeAsString('account-a');

    final target = await runtime.signOut();
    expect(target.target.isLocal, isTrue);
    expect(runtime.current.isLocal, isFalse);
    expect(sessionTokenStore.tokenCount, 0);
    await close(runtime);

    runtime = await bootstrap();
    expect(runtime.current.isLocal, isTrue);
    expect(runtime.current.dataDirectory.path, installationRoot.path);
    expect(await marker.readAsString(), 'account-a');
  });

  test('非官方服务会话在启动前失效并直接切回匿名工作区', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(
      _session(
        userId: 'legacy-account',
        token: 'legacy-token',
        baseUrl: 'https://legacy.invalid',
      ),
    );
    await close(runtime);

    runtime = await bootstrap();
    expect(runtime.current.isLocal, isTrue);
    expect(runtime.current.session, isNull);
    await close(runtime);

    runtime = await bootstrap();
    expect(runtime.current.isLocal, isTrue);
  });

  test('退出在 tombstone 落盘后中断时启动自动完成切回匿名工作区', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    runtime = await bootstrap();
    await runtime.signOut();
    await close(runtime);

    final completedRegistry = File(
      p.join(installationRoot.path, '.kelivo-workspaces', 'registry-v1-b.json'),
    );
    await completedRegistry.delete();

    runtime = await bootstrap();
    expect(runtime.current.isLocal, isTrue);
    expect(runtime.current.session, isNull);
    await close(runtime);

    runtime = await bootstrap();
    expect(runtime.current.isLocal, isTrue);
  });

  test('退出令牌删除中断后启动依据 tombstone 清理残留密文', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    runtime = await bootstrap();
    sessionTokenStore.failNextDelete = true;
    await expectLater(runtime.signOut(), throwsA(isA<StateError>()));
    expect(sessionTokenStore.tokenCount, 1);
    await close(runtime);

    runtime = await bootstrap();
    expect(runtime.current.isLocal, isTrue);
    expect(sessionTokenStore.tokenCount, 0);
  });

  test('退出在 tombstone 后发布注册表失败时不恢复旧凭证', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final blockedRegistrySlot = Directory(
      p.join(installationRoot.path, '.kelivo-workspaces', 'registry-v1-b.json'),
    );
    await blockedRegistrySlot.create();

    await expectLater(runtime.signOut(), throwsA(isA<StateError>()));
    expect(runtime.current.session, isNull);

    await blockedRegistrySlot.delete();
    await close(runtime);
    runtime = await bootstrap();
    expect(runtime.current.isLocal, isTrue);
    expect(runtime.current.session, isNull);
  });

  test('账号配置清理不会读取或删除匿名工作区配置', () async {
    var runtime = await bootstrap();
    var preferences = await SharedPreferences.getInstance();
    await preferences.setString('theme', 'local');
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    SharedPreferences.resetStatic();
    runtime = await bootstrap();
    preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('theme'), isNull);
    await preferences.setString('theme', 'account-a');
    expect(preferences.getString('theme'), 'account-a');
    await preferences.clear();
    expect(preferences.getString('theme'), isNull);
    await preferences.setString('account-only', 'secret');
    await runtime.signOut();
    await close(runtime);

    SharedPreferences.resetStatic();
    runtime = await bootstrap();
    preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('theme'), 'local');
    expect(preferences.getString('account-only'), isNull);
    expect(preferences.getKeys(), isNot(contains('account-only')));
  });

  test('最新注册表发布槽损坏时拒绝回退旧账号', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-b', token: 'token-b'));
    await close(runtime);

    final registryB = File(
      p.join(installationRoot.path, '.kelivo-workspaces', 'registry-v1-b.json'),
    );
    await registryB.writeAsString('{corrupt', flush: true);

    await expectLater(
      AccountWorkspaceRuntime.bootstrap(
        installationRoot: installationRoot,
        sessionTokenStore: sessionTokenStore,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('最新会话发布槽损坏时拒绝回退旧 token', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(
      _session(userId: 'account-a', token: 'old-token'),
    );
    await close(runtime);

    runtime = await bootstrap();
    await runtime.bindAccount(
      _session(userId: 'account-a', token: 'new-token'),
    );
    final accountDirectory = runtime.current.dataDirectory.parent;
    await close(runtime);

    final latestSession = File(
      p.join(accountDirectory.path, 'session-v2-b.json'),
    );
    await latestSession.writeAsString('{corrupt', flush: true);

    await expectLater(
      AccountWorkspaceRuntime.bootstrap(
        installationRoot: installationRoot,
        sessionTokenStore: sessionTokenStore,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('账号附件绝不回退读取另一个账号的绝对路径', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    runtime = await bootstrap();
    final accountARoot = runtime.current.dataDirectory;
    final bindB = await runtime.bindAccount(
      _session(userId: 'account-b', token: 'token-b'),
    );
    final accountBRoot =
        (bindB as AccountWorkspaceRestartRequired).target.dataDirectory;
    final accountBFile = File(
      p.join(accountBRoot.path, 'upload', 'private.txt'),
    );
    await accountBFile.parent.create(recursive: true);
    await accountBFile.writeAsString('account-b');
    final accountBPrivateFile = File(
      p.join(accountBRoot.path, 'private', 'secret.txt'),
    );
    await accountBPrivateFile.parent.create(recursive: true);
    await accountBPrivateFile.writeAsString('account-b-private');
    final accountAFile = File(p.join(accountARoot.path, 'private', 'own.txt'));
    await accountAFile.parent.create(recursive: true);
    await accountAFile.writeAsString('account-a');
    final localWorkspaceFile = File(
      p.join(installationRoot.path, 'private', 'local-secret.txt'),
    );
    await localWorkspaceFile.parent.create(recursive: true);
    await localWorkspaceFile.writeAsString('local');

    await SandboxPathResolver.init();
    final resolved = SandboxPathResolver.fix(accountBFile.path);
    final resolvedPrivate = SandboxPathResolver.fix(accountBPrivateFile.path);
    final resolvedOwn = SandboxPathResolver.fix(accountAFile.path);
    final resolvedLocal = SandboxPathResolver.fix(localWorkspaceFile.path);

    expect(
      p.normalize(resolved),
      p.normalize(p.join(accountARoot.path, 'upload', 'private.txt')),
    );
    expect(p.normalize(resolved), isNot(p.normalize(accountBFile.path)));
    expect(File(resolved).existsSync(), isFalse);
    expect(
      p.normalize(resolvedPrivate),
      isNot(p.normalize(accountBPrivateFile.path)),
    );
    expect(File(resolvedPrivate).existsSync(), isFalse);
    expect(p.normalize(resolvedOwn), p.normalize(accountAFile.path));
    expect(await File(resolvedOwn).readAsString(), 'account-a');
    expect(
      p.normalize(resolvedLocal),
      isNot(p.normalize(localWorkspaceFile.path)),
    );
    expect(File(resolvedLocal).existsSync(), isFalse);
  });

  test('账号持久路径中的父目录段不能穿越到其他账号', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    runtime = await bootstrap();
    final accountARoot = runtime.current.dataDirectory;
    final bindB = await runtime.bindAccount(
      _session(userId: 'account-b', token: 'token-b'),
    );
    final accountBRoot =
        (bindB as AccountWorkspaceRestartRequired).target.dataDirectory;
    final accountBFile = File(
      p.join(accountBRoot.path, 'private', 'parent-traversal.txt'),
    );
    await accountBFile.parent.create(recursive: true);
    await accountBFile.writeAsString('account-b');

    await SandboxPathResolver.init();
    final accountBWorkspaceKey = p.basename(accountBRoot.parent.path);
    final craftedPersistedPath =
        'C:/legacy/Documents/upload/../../../$accountBWorkspaceKey/'
        'data/private/parent-traversal.txt';
    final resolved = SandboxPathResolver.fix(craftedPersistedPath);
    final normalizedResolved = p.normalize(p.absolute(resolved));

    expect(p.isWithin(accountARoot.path, normalizedResolved), isTrue);
    expect(normalizedResolved, isNot(p.normalize(accountBFile.absolute.path)));
    expect(File(resolved).existsSync(), isFalse);
  });

  test('账号持久路径不能通过目录链接读取其他账号', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    runtime = await bootstrap();
    final accountARoot = runtime.current.dataDirectory;
    final bindB = await runtime.bindAccount(
      _session(userId: 'account-b', token: 'token-b'),
    );
    final accountBRoot =
        (bindB as AccountWorkspaceRestartRequired).target.dataDirectory;
    final accountBFile = File(
      p.join(accountBRoot.path, 'private', 'linked-secret.txt'),
    );
    await accountBFile.parent.create(recursive: true);
    await accountBFile.writeAsString('account-b');

    final uploadDirectory = Directory(p.join(accountARoot.path, 'upload'));
    await uploadDirectory.create(recursive: true);
    final linkedAccountPath = p.join(uploadDirectory.path, 'linked-account');
    await _createDirectoryLink(linkedAccountPath, accountBRoot.path);

    await SandboxPathResolver.init();
    final persistedPath = p.join(
      linkedAccountPath,
      'private',
      'linked-secret.txt',
    );
    final resolved = SandboxPathResolver.fix(persistedPath);
    final normalizedResolved = p.normalize(p.absolute(resolved));
    final missingPersistedPath = p.join(
      linkedAccountPath,
      'private',
      'missing-secret.txt',
    );
    final missingResolved = SandboxPathResolver.fix(missingPersistedPath);
    final normalizedMissing = p.normalize(p.absolute(missingResolved));

    expect(p.isWithin(accountARoot.path, normalizedResolved), isTrue);
    expect(File(resolved).existsSync(), isFalse);
    expect(p.isWithin(accountARoot.path, normalizedMissing), isTrue);
    expect(File(missingResolved).existsSync(), isFalse);

    final blockedDirectoryPath = p.join(
      accountARoot.path,
      '.blocked-account-workspace',
    );
    await _createDirectoryLink(blockedDirectoryPath, accountBFile.parent.path);
    final blockedResolved = SandboxPathResolver.fix(
      'C:/external/linked-secret.txt',
    );
    expect(File(blockedResolved).existsSync(), isFalse);
  });

  test('匿名工作区拒绝读取任何账号工作区路径', () async {
    final runtime = await bootstrap();
    final bind = await runtime.bindAccount(
      _session(userId: 'account-a', token: 'token-a'),
    );
    final accountRoot =
        (bind as AccountWorkspaceRestartRequired).target.dataDirectory;
    final privateFile = File(p.join(accountRoot.path, 'private', 'secret.txt'));
    await privateFile.parent.create(recursive: true);
    await privateFile.writeAsString('account-a');
    final externalFile = File(
      p.join(installationRoot.parent.path, '${const Uuid().v4()}.txt'),
    );
    await externalFile.writeAsString('external');
    addTearDown(() async {
      if (await externalFile.exists()) await externalFile.delete();
    });

    await SandboxPathResolver.init();
    final resolved = SandboxPathResolver.fix(privateFile.path);
    final resolvedExternal = SandboxPathResolver.fix(externalFile.path);
    final accountsRoot = p.join(
      installationRoot.path,
      '.kelivo-workspaces',
      'accounts',
    );

    expect(p.normalize(resolved), isNot(p.normalize(privateFile.path)));
    expect(p.isWithin(accountsRoot, resolved), isFalse);
    expect(File(resolved).existsSync(), isFalse);
    expect(
      p.normalize(resolvedExternal),
      isNot(p.normalize(externalFile.path)),
    );
    expect(p.isWithin(installationRoot.path, resolvedExternal), isTrue);
    expect(File(resolvedExternal).existsSync(), isFalse);
  });

  test('账号工作区严格拒绝持久化越界路径但允许显式选择后复制', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final externalDirectory = Directory(
      p.join(installationRoot.parent.path, 'picked-${const Uuid().v4()}'),
    );
    final externalFile = File(p.join(externalDirectory.path, 'avatar.png'));
    await externalDirectory.create(recursive: true);
    await externalFile.writeAsString('selected-by-user');
    try {
      await SandboxPathResolver.init();

      final persisted = SandboxPathResolver.fix(externalFile.path);
      final selected = SandboxPathResolver.resolveUserSelectedSource(
        externalFile.path,
      );

      expect(p.normalize(persisted), isNot(p.normalize(externalFile.path)));
      expect(p.normalize(selected), p.normalize(externalFile.path));

      final provider = UserProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await provider.ready;
      await provider.setAvatarFilePath(externalFile.path);

      final copiedPath = provider.avatarValue;
      expect(copiedPath, isNotNull);
      expect(
        p.isWithin(runtime.current.dataDirectory.path, copiedPath!),
        isTrue,
      );
      expect(await File(copiedPath).readAsString(), 'selected-by-user');
      provider.dispose();
    } finally {
      await externalDirectory.delete(recursive: true);
    }
  });

  test('头像目标目录异常会传播失败且不写入引用', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final externalDirectory = Directory(
      p.join(installationRoot.parent.path, 'picked-${const Uuid().v4()}'),
    );
    final source = File(p.join(externalDirectory.path, 'avatar.png'));
    await externalDirectory.create(recursive: true);
    await source.writeAsString('selected-by-user');
    try {
      await SandboxPathResolver.init();
      final avatarsDir = await AppDirectories.getAvatarsDirectory();
      await avatarsDir.delete(recursive: true);
      await File(avatarsDir.path).writeAsString('blocks-directory-creation');

      final userProvider = UserProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      final settingsProvider = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await Future.wait(<Future<void>>[
        userProvider.ready,
        settingsProvider.ready,
      ]);

      final missingSource = p.join(externalDirectory.path, 'missing.png');
      await expectLater(
        userProvider.setAvatarFilePath(missingSource),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        settingsProvider.setProviderAvatarFilePath('provider-a', missingSource),
        throwsA(isA<FileSystemException>()),
      );

      await expectLater(
        userProvider.setAvatarFilePath(source.path),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        settingsProvider.setProviderAvatarFilePath('provider-a', source.path),
        throwsA(isA<StateError>()),
      );
      expect(userProvider.avatarValue, isNull);
      expect(
        settingsProvider.getProviderConfig('provider-a').avatarValue,
        isNull,
      );
      userProvider.dispose();
      settingsProvider.dispose();
    } finally {
      await externalDirectory.delete(recursive: true);
    }
  });

  test('头像替换和重置不会删除当前账号工作区外的文件', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final externalDirectory = Directory(
      p.join(
        installationRoot.parent.path,
        'foreign-${const Uuid().v4()}',
        'avatars',
      ),
    );
    final userOld = File(p.join(externalDirectory.path, 'user-old.png'));
    final providerOld = File(
      p.join(externalDirectory.path, 'provider-old.png'),
    );
    final userSource = File(p.join(externalDirectory.parent.path, 'user.png'));
    final providerSource = File(
      p.join(externalDirectory.parent.path, 'provider.png'),
    );
    await externalDirectory.create(recursive: true);
    await userOld.writeAsString('foreign-user-avatar');
    await providerOld.writeAsString('foreign-provider-avatar');
    await userSource.writeAsString('new-user-avatar');
    await providerSource.writeAsString('new-provider-avatar');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_type', 'file');
      await prefs.setString('avatar_value', userOld.path.replaceAll('\\', '/'));
      await SandboxPathResolver.init();

      final userProvider = UserProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      final settingsProvider = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await Future.wait(<Future<void>>[
        userProvider.ready,
        settingsProvider.ready,
      ]);

      await userProvider.setAvatarFilePath(userSource.path);
      expect(await userOld.exists(), isTrue);

      const providerKey = 'provider-a';
      final originalConfig = settingsProvider.getProviderConfig(providerKey);
      final foreignConfig = originalConfig.copyWith(
        avatarType: 'file',
        avatarValue: providerOld.path.replaceAll('\\', '/'),
      );
      await settingsProvider.setProviderConfig(providerKey, foreignConfig);
      await settingsProvider.setProviderAvatarFilePath(
        providerKey,
        providerSource.path,
      );
      expect(await providerOld.exists(), isTrue);

      await settingsProvider.setProviderConfig(providerKey, foreignConfig);
      await settingsProvider.resetProviderAvatar(providerKey);
      expect(await providerOld.exists(), isTrue);
      userProvider.dispose();
      settingsProvider.dispose();
    } finally {
      await externalDirectory.parent.delete(recursive: true);
    }
  });

  test('账号受管子目录链接不能承载头像或字体写入', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final redirectedRoot = Directory(
      p.join(installationRoot.path, 'redirected-managed-assets'),
    );
    final redirectedAvatars = Directory(p.join(redirectedRoot.path, 'avatars'));
    final redirectedFonts = Directory(p.join(redirectedRoot.path, 'fonts'));
    await redirectedAvatars.create(recursive: true);
    await redirectedFonts.create(recursive: true);
    await _createDirectoryLink(
      p.join(runtime.current.dataDirectory.path, 'avatars'),
      redirectedAvatars.path,
    );
    await _createDirectoryLink(
      p.join(runtime.current.dataDirectory.path, 'fonts'),
      redirectedFonts.path,
    );

    final selectedAvatar = File(p.join(redirectedRoot.path, 'selected.png'));
    final selectedFont = File(p.join(redirectedRoot.path, 'selected.ttf'));
    await selectedAvatar.writeAsString('avatar');
    await selectedFont.writeAsBytes(const <int>[0, 1, 0, 0]);
    final userProvider = UserProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    final settingsProvider = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await Future.wait(<Future<void>>[
      userProvider.ready,
      settingsProvider.ready,
    ]);

    await expectLater(
      userProvider.setAvatarFilePath(selectedAvatar.path),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      settingsProvider.setProviderAvatarFilePath(
        'provider-a',
        selectedAvatar.path,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      settingsProvider.setAppFontFromLocal(path: selectedFont.path),
      throwsA(isA<StateError>()),
    );
    expect(await redirectedAvatars.list().toList(), isEmpty);
    expect(await redirectedFonts.list().toList(), isEmpty);
    userProvider.dispose();
    settingsProvider.dispose();
  });

  test('用户头像持久化返回失败时保留旧引用并清理本次副本', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();
    await SandboxPathResolver.init();

    final selectedDirectory = Directory(
      p.join(installationRoot.parent.path, 'picked-${const Uuid().v4()}'),
    );
    final firstSource = File(p.join(selectedDirectory.path, 'first.png'));
    final secondSource = File(p.join(selectedDirectory.path, 'second.png'));
    await selectedDirectory.create(recursive: true);
    await firstSource.writeAsString('first');
    await secondSource.writeAsString('second');
    try {
      final provider = UserProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await provider.ready;
      await provider.setAvatarFilePath(firstSource.path);
      final previousPath = provider.avatarValue!;
      final preferences = await SharedPreferences.getInstance();
      SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
        _physicalPreferenceData(
          preferences,
          prefix: runtime.current.preferencesPrefix,
        ),
        failSetKeySuffix: 'avatar_value',
      );

      await expectLater(
        provider.setAvatarFilePath(secondSource.path),
        throwsA(isA<StateError>()),
      );

      expect(provider.avatarType, 'file');
      expect(p.normalize(provider.avatarValue!), p.normalize(previousPath));
      expect(await File(previousPath).readAsString(), 'first');
      final avatars = await AppDirectories.getAvatarsDirectory();
      expect(
        await avatars
            .list()
            .where((entry) => entry is File)
            .map((entry) => p.normalize(entry.path))
            .toList(),
        <String>[p.normalize(previousPath)],
      );
      await preferences.reload();
      expect(
        p.normalize(preferences.getString('avatar_value')!),
        p.normalize(previousPath),
      );

      SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
        _physicalPreferenceData(
          preferences,
          prefix: runtime.current.preferencesPrefix,
        ),
        failRemoveKeySuffix: 'avatar_value',
      );
      await expectLater(provider.resetAvatar(), throwsA(isA<StateError>()));
      expect(provider.avatarType, 'file');
      expect(p.normalize(provider.avatarValue!), p.normalize(previousPath));
      expect(await File(previousPath).exists(), isTrue);
      provider.dispose();
    } finally {
      await selectedDirectory.delete(recursive: true);
    }
  });

  test('用户资料初始化失败后本地写入保持关闭且不发布新状态', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();
    await SandboxPathResolver.init();

    final avatars = await AppDirectories.getAvatarsDirectory();
    final currentAvatar = File(
      p.join(avatars.path, 'avatar_00000000-0000-0000-0000-000000000001.png'),
    );
    await currentAvatar.writeAsString('avatar');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('avatar_type', 'file');
    await preferences.setString(
      'avatar_value',
      '/var/mobile/Containers/Data/Application/OLD/Documents/avatars/'
          '${p.basename(currentAvatar.path)}',
    );
    SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
      _physicalPreferenceData(
        preferences,
        prefix: runtime.current.preferencesPrefix,
      ),
      failSetKeySuffix: 'avatar_value',
    );
    final user = UserProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );

    await expectLater(user.ready, throwsA(isA<StateError>()));
    await expectLater(user.setName('不应提交'), throwsA(isA<StateError>()));

    expect(user.name, 'User');
    await preferences.reload();
    expect(preferences.getString('user_name'), isNull);
    user.dispose();
  });

  test('用户头像切换类型和重置会清理不再引用的受管副本', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();
    await SandboxPathResolver.init();

    final selectedDirectory = Directory(
      p.join(installationRoot.parent.path, 'picked-${const Uuid().v4()}'),
    );
    final source = File(p.join(selectedDirectory.path, 'avatar.png'));
    await selectedDirectory.create(recursive: true);
    await source.writeAsString('avatar');
    try {
      final provider = UserProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await provider.ready;

      await provider.setAvatarFilePath(source.path);
      final emojiReplacedPath = provider.avatarValue!;
      await provider.setAvatarEmoji('🙂');
      expect(await File(emojiReplacedPath).exists(), isFalse);

      await provider.setAvatarFilePath(source.path);
      final resetPath = provider.avatarValue!;
      await provider.resetAvatar();
      expect(await File(resetPath).exists(), isFalse);
      provider.dispose();
    } finally {
      await selectedDirectory.delete(recursive: true);
    }
  });

  test('供应商头像文件操作等待实体锁且类型切换与删除回收孤儿副本', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();
    await SandboxPathResolver.init();

    final selectedDirectory = Directory(
      p.join(installationRoot.parent.path, 'picked-${const Uuid().v4()}'),
    );
    final source = File(p.join(selectedDirectory.path, 'avatar.png'));
    await selectedDirectory.create(recursive: true);
    await source.writeAsString('avatar');
    try {
      final executor = _BlockingFirstWriteExecutor();
      final settings = SettingsProvider(syncWriteExecutor: executor);
      await settings.ready;
      final avatars = await AppDirectories.getAvatarsDirectory();

      final occupyingWrite = settings.setProviderAvatarEmoji('provider-a', 'A');
      await executor.firstWriteEntered;
      final waitingFileWrite = settings.setProviderAvatarFilePath(
        'provider-a',
        source.path,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await avatars.list().toList(), isEmpty);

      executor.releaseFirstWrite();
      await Future.wait(<Future<void>>[occupyingWrite, waitingFileWrite]);
      final firstManagedPath = settings
          .getProviderConfig('provider-a')
          .avatarValue!;
      expect(await File(firstManagedPath).exists(), isTrue);

      await settings.setProviderAvatarIcon(
        'provider-a',
        'assets/icons/openai.svg',
      );
      expect(await File(firstManagedPath).exists(), isFalse);

      await settings.setProviderAvatarFilePath('provider-a', source.path);
      final deletedProviderPath = settings
          .getProviderConfig('provider-a')
          .avatarValue!;
      await settings.removeProviderConfig('provider-a');
      expect(await File(deletedProviderPath).exists(), isFalse);
      settings.dispose();
    } finally {
      await selectedDirectory.delete(recursive: true);
    }
  });

  test('供应商头像持久化返回失败时保留旧文件并清理本次副本', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();
    await SandboxPathResolver.init();

    final selectedDirectory = Directory(
      p.join(installationRoot.parent.path, 'picked-${const Uuid().v4()}'),
    );
    final firstSource = File(p.join(selectedDirectory.path, 'first.png'));
    final secondSource = File(p.join(selectedDirectory.path, 'second.png'));
    await selectedDirectory.create(recursive: true);
    await firstSource.writeAsString('first');
    await secondSource.writeAsString('second');
    try {
      final settings = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await settings.ready;
      await settings.setProviderAvatarFilePath('provider-a', firstSource.path);
      final previousPath = settings
          .getProviderConfig('provider-a')
          .avatarValue!;
      final preferences = await SharedPreferences.getInstance();
      SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
        _physicalPreferenceData(
          preferences,
          prefix: runtime.current.preferencesPrefix,
        ),
        failSetKeySuffix: 'provider_configs_v1',
      );

      await expectLater(
        settings.setProviderAvatarFilePath('provider-a', secondSource.path),
        throwsA(isA<StateError>()),
      );

      expect(
        p.normalize(settings.getProviderConfig('provider-a').avatarValue!),
        p.normalize(previousPath),
      );
      expect(await File(previousPath).readAsString(), 'first');
      final avatars = await AppDirectories.getAvatarsDirectory();
      expect(
        await avatars
            .list()
            .where((entry) => entry is File)
            .map((entry) => p.normalize(entry.path))
            .toList(),
        <String>[p.normalize(previousPath)],
      );

      SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
        _physicalPreferenceData(
          preferences,
          prefix: runtime.current.preferencesPrefix,
        ),
        failSetKeySuffix: 'provider_configs_v1',
      );
      await expectLater(
        settings.removeProviderConfig('provider-a'),
        throwsA(isA<StateError>()),
      );
      expect(
        p.normalize(settings.getProviderConfig('provider-a').avatarValue!),
        p.normalize(previousPath),
      );
      expect(await File(previousPath).exists(), isTrue);
      settings.dispose();
    } finally {
      await selectedDirectory.delete(recursive: true);
    }
  });

  test('不同供应商并发更新不会覆盖同一聚合配置中的另一项', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    final preferences = await SharedPreferences.getInstance();
    final store = _BlockingFirstPreferenceSetStore(
      _physicalPreferenceData(
        preferences,
        prefix: runtime.current.preferencesPrefix,
      ),
      keySuffix: 'provider_configs_v1',
    );
    SharedPreferencesStorePlatform.instance = store;

    final first = settings.setProviderConfig(
      'provider-a',
      settings.getProviderConfig('provider-a').copyWith(name: '并发供应商 A'),
    );
    await store.firstSetEntered;
    final second = settings.setProviderConfig(
      'provider-b',
      settings.getProviderConfig('provider-b').copyWith(name: '并发供应商 B'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    store.releaseFirstSet();
    await Future.wait(<Future<void>>[first, second]);

    expect(settings.getProviderConfig('provider-a').name, '并发供应商 A');
    expect(settings.getProviderConfig('provider-b').name, '并发供应商 B');
    final persisted =
        jsonDecode(
              (await SharedPreferences.getInstance()).getString(
                'provider_configs_v1',
              )!,
            )
            as Map<String, dynamic>;
    expect(persisted.keys, containsAll(<String>['provider-a', 'provider-b']));
    settings.dispose();
  });

  test('删除模型清理选择项失败时补偿供应商配置且不发布内存', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    const providerKey = 'provider-a';
    const removedModel = 'remove-me';
    await settings.setProviderConfig(
      providerKey,
      settings
          .getProviderConfig(providerKey)
          .copyWith(models: const <String>['keep', removedModel]),
    );
    await settings.setCurrentModel(providerKey, removedModel);
    final preferences = await SharedPreferences.getInstance();
    final originalConfigs = preferences.getString('provider_configs_v1');
    SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
      _physicalPreferenceData(
        preferences,
        prefix: runtime.current.preferencesPrefix,
      ),
      failRemoveKeySuffix: 'selected_model_v1',
    );

    await expectLater(
      settings.deleteModels(providerKey, const <String>{removedModel}),
      throwsA(isA<StateError>()),
    );

    expect(settings.getProviderConfig(providerKey).models, const <String>[
      'keep',
      removedModel,
    ]);
    expect(settings.currentModelProvider, providerKey);
    expect(settings.currentModelId, removedModel);
    await preferences.reload();
    expect(preferences.getString('provider_configs_v1'), originalConfigs);
    expect(
      preferences.getString('selected_model_v1'),
      '$providerKey::$removedModel',
    );
    settings.dispose();
  });

  test('远端供应商分组更新等待聚合配置事务完成', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    final preferences = await SharedPreferences.getInstance();
    final store = _BlockingFirstPreferenceSetStore(
      _physicalPreferenceData(
        preferences,
        prefix: runtime.current.preferencesPrefix,
      ),
      keySuffix: 'provider_configs_v1',
    );
    SharedPreferencesStorePlatform.instance = store;

    final configMutation = settings.setProviderConfig(
      'provider-a',
      settings.getProviderConfig('provider-a').copyWith(name: '供应商 A'),
    );
    await store.firstSetEntered;
    final groupingMutation = settings.syncApplyProviderGrouping(
      order: settings.providersOrder,
      groups: const <ProviderGroup>[
        ProviderGroup(id: 'group-a', name: '分组 A', createdAt: 1),
      ],
      assignments: const <String, String>{'provider-a': 'group-a'},
      ungroupedPosition: 0,
    );
    await Future<void>(() {});

    expect(settings.providerGroups, isEmpty);
    expect(settings.groupIdForProvider('provider-a'), isNull);

    store.releaseFirstSet();
    await Future.wait(<Future<void>>[configMutation, groupingMutation]);
    expect(settings.providerGroups.single.name, '分组 A');
    expect(settings.groupIdForProvider('provider-a'), 'group-a');
    settings.dispose();
  });

  test('供应商分组多键持久化失败时不发布内存且回滚已写键', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    final originalGroupId = await settings.createGroup('原分组');
    await settings.setProviderGroup('KelivoIN', originalGroupId);
    final originalGroups = settings.providerGroups;
    final originalAssignments = settings.providerGroupAssignments;
    final originalPosition = settings.providerUngroupedDisplayIndex;
    final preferences = await SharedPreferences.getInstance();
    final originalGroupJson = preferences.getString('provider_groups_v1');
    final originalAssignmentJson = preferences.getString(
      'provider_group_map_v1',
    );
    SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
      _physicalPreferenceData(
        preferences,
        prefix: runtime.current.preferencesPrefix,
      ),
      failSetKeySuffix: 'provider_group_map_v1',
    );

    await expectLater(
      settings.syncApplyProviderGrouping(
        order: settings.providersOrder,
        groups: const <ProviderGroup>[
          ProviderGroup(id: 'replacement', name: '替换分组', createdAt: 2),
        ],
        assignments: const <String, String>{'KelivoIN': 'replacement'},
        ungroupedPosition: 0,
      ),
      throwsA(isA<StateError>()),
    );

    expect(settings.providerGroups, originalGroups);
    expect(settings.providerGroupAssignments, originalAssignments);
    expect(settings.providerUngroupedDisplayIndex, originalPosition);
    await preferences.reload();
    expect(preferences.getString('provider_groups_v1'), originalGroupJson);
    expect(
      preferences.getString('provider_group_map_v1'),
      originalAssignmentJson,
    );
    settings.dispose();
  });

  test('供应商顺序持久化失败时不发布新顺序', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    final originalOrder = List<String>.of(settings.providersOrder);
    final preferences = await SharedPreferences.getInstance();
    final persistedOrder = preferences.getStringList('providers_order_v1');
    SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
      _physicalPreferenceData(
        preferences,
        prefix: runtime.current.preferencesPrefix,
      ),
      failSetKeySuffix: 'providers_order_v1',
    );

    await expectLater(
      settings.setProvidersOrder(originalOrder.reversed.toList()),
      throwsA(isA<StateError>()),
    );

    expect(settings.providersOrder, originalOrder);
    await preferences.reload();
    expect(preferences.getStringList('providers_order_v1'), persistedOrder);
    settings.dispose();
  });

  test('本地供应商分组持久化失败时不保留未提交分组', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    final preferences = await SharedPreferences.getInstance();
    SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
      _physicalPreferenceData(
        preferences,
        prefix: runtime.current.preferencesPrefix,
      ),
      failSetKeySuffix: 'provider_group_map_v1',
    );

    await expectLater(
      settings.createGroup('未提交分组'),
      throwsA(isA<StateError>()),
    );

    expect(settings.providerGroups, isEmpty);
    settings.dispose();
  });

  test('供应商头像复制中途失败时清理已创建的部分目标', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();
    await SandboxPathResolver.init();

    final selectedDirectory = Directory(
      p.join(installationRoot.parent.path, 'picked-${const Uuid().v4()}'),
    );
    final source = File(p.join(selectedDirectory.path, 'avatar.png'));
    await selectedDirectory.create(recursive: true);
    await source.writeAsString('avatar');
    try {
      final settings = SettingsProvider.forTesting(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        managedFileCopy: (source, destination) async {
          await source.copy(destination.path);
          throw FileSystemException('模拟复制中途失败', destination.path);
        },
      );
      await settings.ready;
      final avatars = await AppDirectories.getAvatarsDirectory();

      await expectLater(
        settings.setProviderAvatarFilePath('provider-a', source.path),
        throwsA(isA<FileSystemException>()),
      );

      expect(await avatars.list().toList(), isEmpty);
      expect(settings.getProviderConfig('provider-a').avatarValue, isNull);
      settings.dispose();
    } finally {
      await selectedDirectory.delete(recursive: true);
    }
  });

  test('用户头像复制中途失败时清理已创建的部分目标', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();
    await SandboxPathResolver.init();

    final selectedDirectory = Directory(
      p.join(installationRoot.parent.path, 'picked-${const Uuid().v4()}'),
    );
    final source = File(p.join(selectedDirectory.path, 'avatar.png'));
    await selectedDirectory.create(recursive: true);
    await source.writeAsString('avatar');
    try {
      final user = UserProvider.forTesting(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        managedFileCopy: (source, destination) async {
          await source.copy(destination.path);
          throw FileSystemException('模拟复制中途失败', destination.path);
        },
      );
      await user.ready;
      final avatars = await AppDirectories.getAvatarsDirectory();

      await expectLater(
        user.setAvatarFilePath(source.path),
        throwsA(isA<FileSystemException>()),
      );

      expect(await avatars.list().toList(), isEmpty);
      expect(user.avatarValue, isNull);
      user.dispose();
    } finally {
      await selectedDirectory.delete(recursive: true);
    }
  });

  test('用户与供应商头像只清理自身命名空间且陌生文件保持', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();
    await SandboxPathResolver.init();

    final selectedDirectory = Directory(
      p.join(installationRoot.parent.path, 'picked-${const Uuid().v4()}'),
    );
    final source = File(p.join(selectedDirectory.path, 'avatar.png'));
    await selectedDirectory.create(recursive: true);
    await source.writeAsString('avatar');
    try {
      final settings = SettingsProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      final user = UserProvider(
        syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      );
      await Future.wait<void>(<Future<void>>[settings.ready, user.ready]);

      await user.setAvatarFilePath(source.path);
      final userAvatarPath = user.avatarValue!;
      await settings.setProviderConfig(
        'provider-a',
        settings
            .getProviderConfig('provider-a')
            .copyWith(avatarType: 'file', avatarValue: userAvatarPath),
      );
      await settings.resetProviderAvatar('provider-a');
      expect(await File(userAvatarPath).exists(), isTrue);
      await settings.setProviderConfig(
        'provider-a',
        settings
            .getProviderConfig('provider-a')
            .copyWith(avatarType: 'file', avatarValue: userAvatarPath),
      );
      await user.resetAvatar();
      expect(await File(userAvatarPath).exists(), isTrue);

      await settings.setProviderAvatarFilePath('provider-b', source.path);
      final providerAvatarPath = settings
          .getProviderConfig('provider-b')
          .avatarValue!;
      await user.syncApplyProfile(
        name: user.name,
        replaceAvatar: true,
        avatarType: 'file',
        avatarValue: providerAvatarPath,
      );
      await settings.resetProviderAvatar('provider-b');
      expect(await File(providerAvatarPath).exists(), isTrue);
      await user.resetAvatar();
      expect(await File(providerAvatarPath).exists(), isTrue);

      final avatars = await AppDirectories.getAvatarsDirectory();
      final unknownUserPath = p.join(avatars.path, 'legacy-user-avatar.png');
      await File(unknownUserPath).writeAsString('legacy-user');
      await user.syncApplyProfile(
        name: user.name,
        replaceAvatar: true,
        avatarType: 'file',
        avatarValue: unknownUserPath,
      );
      await user.resetAvatar();
      expect(await File(unknownUserPath).exists(), isTrue);

      final unknownProviderPath = p.join(
        avatars.path,
        'legacy-provider-avatar.png',
      );
      await File(unknownProviderPath).writeAsString('legacy-provider');
      await settings.setProviderConfig(
        'provider-c',
        settings
            .getProviderConfig('provider-c')
            .copyWith(avatarType: 'file', avatarValue: unknownProviderPath),
      );
      await settings.resetProviderAvatar('provider-c');
      expect(await File(unknownProviderPath).exists(), isTrue);
      settings.dispose();
      user.dispose();
    } finally {
      await selectedDirectory.delete(recursive: true);
    }
  });

  test('新增供应商顺序持久化失败时配置和顺序一起回滚', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);
    runtime = await bootstrap();

    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    final originalOrder = List<String>.of(settings.providersOrder);
    final preferences = await SharedPreferences.getInstance();
    final originalConfigs = preferences.getString('provider_configs_v1');
    SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
      _physicalPreferenceData(
        preferences,
        prefix: runtime.current.preferencesPrefix,
      ),
      failSetKeySuffix: 'providers_order_v1',
    );

    await expectLater(
      settings.setProviderConfig(
        'custom-atomic',
        ProviderConfig.defaultsFor('custom-atomic'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(settings.providerConfigs, isNot(contains('custom-atomic')));
    expect(settings.providersOrder, originalOrder);
    await preferences.reload();
    expect(preferences.getString('provider_configs_v1'), originalConfigs);
    expect(preferences.getStringList('providers_order_v1'), originalOrder);
    settings.dispose();
  });

  test('全局代理密码写入返回 false 时保留既有密码且显式失败', () async {
    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    await settings.setGlobalProxyPassword('old-secret');
    final preferences = await SharedPreferences.getInstance();
    SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
      _physicalPreferenceData(preferences, prefix: 'flutter.'),
      failSetKeySuffix: 'global_proxy_password_v1',
    );

    await expectLater(
      settings.setGlobalProxyPassword('new-secret'),
      throwsA(isA<StateError>()),
    );

    expect(settings.globalProxyPassword, 'old-secret');
    await preferences.reload();
    expect(preferences.getString('global_proxy_password_v1'), 'old-secret');
    settings.dispose();
  });

  test('全局代理密码删除返回 false 时保留既有密码且显式失败', () async {
    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    await settings.setGlobalProxyPassword('old-secret');
    final preferences = await SharedPreferences.getInstance();
    SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
      _physicalPreferenceData(preferences, prefix: 'flutter.'),
      failRemoveKeySuffix: 'global_proxy_password_v1',
    );

    await expectLater(
      settings.setGlobalProxyPassword(''),
      throwsA(isA<StateError>()),
    );

    expect(settings.globalProxyPassword, 'old-secret');
    await preferences.reload();
    expect(preferences.getString('global_proxy_password_v1'), 'old-secret');
    settings.dispose();
  });

  test('嵌入模型迁移写入返回 false 时不发布内存结果且保留重试标记', () async {
    const providerKey = 'migration-provider';
    const modelId = 'embedding-model';
    final originalConfig = ProviderConfig.defaultsFor(providerKey).copyWith(
      models: const <String>[modelId],
      modelOverrides: const <String, dynamic>{
        modelId: <String, dynamic>{
          'type': 'embedding',
          'tools': <String>['search'],
          'dimension': 1536,
        },
      },
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'provider_configs_v1': jsonEncode(<String, Object?>{
        providerKey: originalConfig.toJson(),
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    SharedPreferencesStorePlatform.instance = _FailingPreferenceStore(
      _physicalPreferenceData(preferences, prefix: 'flutter.'),
      failSetKeySuffix: 'provider_configs_v1',
    );

    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;

    expect(
      settings.getProviderConfig(providerKey).modelOverrides[modelId],
      containsPair('tools', const <String>['search']),
    );
    await preferences.reload();
    expect(preferences.getInt('migrations_version_v1'), isNull);
    final persisted =
        jsonDecode(preferences.getString('provider_configs_v1')!)
            as Map<String, dynamic>;
    expect(
      (persisted[providerKey] as Map<String, dynamic>)['modelOverrides'],
      containsPair(modelId, containsPair('tools', const <String>['search'])),
    );
    settings.dispose();
  });
}

Future<List<CloudSyncOutboxMutation>> _captureAccountProviderUpload({
  required AccountWorkspaceContext workspace,
  required SettingsProvider settings,
}) async {
  final session = workspace.session;
  if (session == null) {
    throw StateError('账号上传测试必须运行在已登录工作区');
  }
  Hive.init(workspace.dataDirectory.path);
  final store = await CloudSyncStore.open(
    boxName: 'account-workspace-cloud-sync-boundary-test',
  );
  final journal = SyncWriteJournal(
    store: store,
    journalScopeId: 'account-boundary-${workspace.workspaceKey}',
    initialSession: session,
  );
  final transport = _AccountBoundaryTransport();
  final adapter = _ProviderConfigBoundaryAdapter(settings);
  final coordinator = CloudSyncCoordinator(
    session,
    transport,
    store,
    journal,
    adapters: <SyncEntityAdapter>[adapter],
  );
  try {
    await store.savePullCursor(session, 'cursor-0');
    await coordinator.synchronize(
      rescanEntityTypes: const <String>{'provider'},
    );
    return List<CloudSyncOutboxMutation>.unmodifiable(
      transport.pushedMutations,
    );
  } finally {
    await journal.close();
    await store.close();
    await Hive.close();
  }
}

final class _ProviderConfigBoundaryAdapter implements SyncEntityAdapter {
  _ProviderConfigBoundaryAdapter(this._settings);

  final SettingsProvider _settings;

  @override
  int get applyPriority => 0;

  @override
  Set<String> get entityTypes => const <String>{'provider'};

  Iterable<LocalSyncEntity> get _entities sync* {
    for (final providerId in _settings.providerConfigs.keys) {
      if (!providerId.startsWith('account-')) continue;
      yield LocalSyncEntity(
        entityType: 'provider',
        entityId: providerId,
        payload: <String, Object?>{'name': providerId},
      );
    }
  }

  @override
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) => apply();

  @override
  Future<LocalSyncEntity?> exportLocalEntity(SyncEntityKey key) async {
    for (final entity in _entities) {
      if (entity.key == key) return entity;
    }
    return null;
  }

  @override
  Future<Map<SyncEntityKey, LocalSyncEntity>> exportLocalEntitiesForKeys(
    Set<SyncEntityKey> keys,
  ) async {
    return <SyncEntityKey, LocalSyncEntity>{
      for (final entity in _entities)
        if (keys.contains(entity.key)) entity.key: entity,
    };
  }

  @override
  Future<List<LocalSyncEntity>> exportLocalEntities() async {
    return List<LocalSyncEntity>.unmodifiable(_entities);
  }

  @override
  Future<void> applyRemoteDelete(SyncEntityKey key) async {}

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {}
}

final class _AccountBoundaryTransport implements CloudSyncTransport {
  final List<CloudSyncOutboxMutation> pushedMutations =
      <CloudSyncOutboxMutation>[];
  var _changeSeq = 0;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'cursor-1',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) async {
    pushedMutations.addAll(mutations);
    return <CloudSyncMutationResult>[
      for (final mutation in mutations)
        CloudSyncMutationResult(
          mutationId: mutation.mutationId,
          status: CloudSyncMutationStatus.applied,
          retryable: false,
          revision: 1,
          changeSeq: ++_changeSeq,
        ),
    ];
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) {
    throw StateError('账号边界测试已有游标，不应请求全量快照');
  }
}

final class _BlockingFirstWriteExecutor implements SyncWriteExecutor {
  final Completer<void> _firstWriteEntered = Completer<void>();
  final Completer<void> _releaseFirstWrite = Completer<void>();
  Future<void> _tail = Future<void>.value();
  var _writeCount = 0;

  Future<void> get firstWriteEntered => _firstWriteEntered.future;

  void releaseFirstWrite() {
    if (!_releaseFirstWrite.isCompleted) {
      _releaseFirstWrite.complete();
    }
  }

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return runLocalBatch(keys: <SyncEntityKey>[key], write: write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) async {
    final previous = _tail;
    final completed = Completer<void>();
    _tail = completed.future;
    await previous;
    try {
      _writeCount++;
      if (_writeCount == 1) {
        _firstWriteEntered.complete();
        await _releaseFirstWrite.future;
      }
      return await write();
    } finally {
      completed.complete();
    }
  }
}

final class _FailingPreferenceStore extends InMemorySharedPreferencesStore {
  _FailingPreferenceStore(
    super.data, {
    this.failSetKeySuffix,
    this.failRemoveKeySuffix,
  }) : super.withData();

  final String? failSetKeySuffix;
  final String? failRemoveKeySuffix;
  var _setFailed = false;
  var _removeFailed = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!_setFailed &&
        failSetKeySuffix != null &&
        key.endsWith(failSetKeySuffix!)) {
      _setFailed = true;
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (!_removeFailed &&
        failRemoveKeySuffix != null &&
        key.endsWith(failRemoveKeySuffix!)) {
      _removeFailed = true;
      return false;
    }
    return super.remove(key);
  }
}

final class _BlockingFirstPreferenceSetStore
    extends InMemorySharedPreferencesStore {
  _BlockingFirstPreferenceSetStore(super.data, {required this.keySuffix})
    : super.withData();

  final String keySuffix;
  final Completer<void> _firstSetEntered = Completer<void>();
  final Completer<void> _releaseFirstSet = Completer<void>();
  var _matchingSetCount = 0;

  Future<void> get firstSetEntered => _firstSetEntered.future;

  void releaseFirstSet() {
    if (!_releaseFirstSet.isCompleted) {
      _releaseFirstSet.complete();
    }
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith(keySuffix)) {
      _matchingSetCount += 1;
      if (_matchingSetCount == 1) {
        _firstSetEntered.complete();
        await _releaseFirstSet.future;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

final class _MemoryAccountSessionTokenStore
    implements AccountSessionTokenStore {
  final Map<String, String> _tokens = <String, String>{};
  bool failNextDelete = false;

  int get tokenCount => _tokens.length;

  void clear() => _tokens.clear();

  @override
  Future<AccountSessionTokenReference> writeToken({
    required Directory accountDirectory,
    required String workspaceKey,
    required String token,
    required AccountSessionTokenReference? currentReference,
    required RestoreDurability durability,
  }) async {
    final reference = AccountSessionTokenReference.next(currentReference);
    _tokens[_key(accountDirectory, reference)] = token;
    return reference;
  }

  @override
  Future<String> readToken({
    required Directory accountDirectory,
    required String workspaceKey,
    required AccountSessionTokenReference reference,
  }) async {
    final token = _tokens[_key(accountDirectory, reference)];
    if (token == null) throw StateError('account_session_token_missing');
    return token;
  }

  @override
  Future<void> deleteTokens({
    required Directory accountDirectory,
    required AccountSessionTokenReference? keep,
    required RestoreDurability durability,
  }) async {
    if (failNextDelete) {
      failNextDelete = false;
      throw StateError('account_session_token_delete_interrupted');
    }
    final prefix = '${p.normalize(accountDirectory.absolute.path)}|';
    final keepKey = keep == null ? null : _key(accountDirectory, keep);
    _tokens.removeWhere((key, _) => key.startsWith(prefix) && key != keepKey);
  }

  static String _key(
    Directory accountDirectory,
    AccountSessionTokenReference reference,
  ) {
    return '${p.normalize(accountDirectory.absolute.path)}|'
        '${reference.slot}|${reference.generation}';
  }
}

Map<String, Object> _physicalPreferenceData(
  SharedPreferences preferences, {
  required String prefix,
}) {
  return <String, Object>{
    for (final key in preferences.getKeys())
      if (preferences.get(key) case final Object value) '$prefix$key': value,
  };
}

Future<void> _createDirectoryLink(String linkPath, String targetPath) async {
  if (!Platform.isWindows) {
    await Link(linkPath).create(targetPath);
    return;
  }
  final result = await Process.run(
    'pwsh',
    <String>[
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'New-Item -ItemType Junction -Path $env:KELIVO_LINK_PATH '
          r'-Target $env:KELIVO_LINK_TARGET | Out-Null',
    ],
    environment: <String, String>{
      'KELIVO_LINK_PATH': linkPath,
      'KELIVO_LINK_TARGET': targetPath,
    },
  );
  if (result.exitCode != 0) {
    throw StateError(
      'account_workspace_junction_setup_failed:${result.stderr}',
    );
  }
}

bool _containsBytes(List<int> haystack, List<int> needle) {
  if (needle.isEmpty) return true;
  for (var start = 0; start + needle.length <= haystack.length; start++) {
    var matches = true;
    for (var offset = 0; offset < needle.length; offset++) {
      if (haystack[start + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

CloudSyncAccountSession _session({
  required String userId,
  required String token,
  String baseUrl = defaultCloudSyncBaseUrl,
}) {
  return CloudSyncAccountSession(
    baseUrl: baseUrl,
    token: token,
    userId: userId,
    loginName: userId,
    displayName: userId,
    role: CloudSyncUserRole.user,
    attachmentQuotaBytes: 1024,
    deviceId: 'device-$userId',
    deviceName: 'Device $userId',
    platform: CloudSyncPlatform.windows,
    clientVersion: '1.0.0',
    deviceCreatedAt: DateTime.utc(2026, 7, 18),
  );
}
