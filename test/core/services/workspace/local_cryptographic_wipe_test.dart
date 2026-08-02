import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/storage/durable_shared_preferences_eraser.dart';
import 'package:Kelivo/core/services/storage/durable_shared_preferences_store.dart';
import 'package:Kelivo/core/services/workspace/installation_operation_lease.dart';
import 'package:Kelivo/core/services/workspace/local_cryptographic_wipe.dart';
import 'package:Kelivo/core/services/workspace/local_cryptographic_wipe_startup.dart';
import 'package:Kelivo/core/services/workspace/local_wipe_marker_topology.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_durable_preferences/kelivo_durable_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  const deviceId = '00000000-0000-4000-8000-000000000001';
  const otherDeviceId = '00000000-0000-4000-8000-000000000002';
  const mutationId = '00000000-0000-4000-8000-000000000003';
  late Directory root;
  late Directory installationRoot;
  late Directory cacheRoot;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo-local-wipe-');
    installationRoot = Directory('${root.path}${Platform.pathSeparator}data');
    cacheRoot = Directory('${root.path}${Platform.pathSeparator}cache');
    await installationRoot.create();
    await cacheRoot.create();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> wipeInstallationRootForTest({
    required String preservedEntryName,
  }) async {
    final entities = await installationRoot.list(followLinks: false).toList();
    for (final entity in entities) {
      final name = entity.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      if (name == preservedEntryName) continue;
      await entity.delete(recursive: true);
    }
  }

  InstallationLocalCryptographicWipe createWipe({
    bool isSupported = true,
    Future<Directory> Function()? applicationCacheDirectory,
    Future<void> Function()? deleteAllSecureSlots,
    LocalInstallationRootWipe? wipeInstallationRoot,
    Future<void> Function()? clearAllPreferences,
    RestoreDurability? durability,
  }) {
    return InstallationLocalCryptographicWipe(
      installationRoot: installationRoot,
      isSupported: isSupported,
      applicationCacheDirectory:
          applicationCacheDirectory ?? () async => cacheRoot,
      deleteAllSecureSlots: deleteAllSecureSlots ?? () async {},
      wipeInstallationRoot: wipeInstallationRoot ?? wipeInstallationRootForTest,
      clearAllPreferences: clearAllPreferences ?? () async {},
      durability: durability,
    );
  }

  Future<void> markConfirmed(
    InstallationLocalCryptographicWipe wipe, {
    String targetDeviceId = deviceId,
    String targetMutationId = mutationId,
  }) async {
    await wipe.markRevocationRequested(
      deviceId: targetDeviceId,
      mutationId: targetMutationId,
    );
    await wipe.markRevocationConfirmed(
      deviceId: targetDeviceId,
      mutationId: targetMutationId,
    );
  }

  Future<void> writeInstallationFixture() async {
    await File(
      '${installationRoot.path}${Platform.pathSeparator}account-a.db',
    ).writeAsString('ciphertext');
    final nested = Directory(
      '${installationRoot.path}${Platform.pathSeparator}.kelivo-workspaces'
      '${Platform.pathSeparator}accounts${Platform.pathSeparator}account-b',
    );
    await nested.create(recursive: true);
    await File(
      '${nested.path}${Platform.pathSeparator}kelivo.db-wal',
    ).writeAsString('ciphertext');
    await File(
      '${cacheRoot.path}${Platform.pathSeparator}avatar.bin',
    ).writeAsString('cached');
  }

  Future<List<FileSystemEntity>> installationEntities() {
    return installationRoot.list(followLinks: false).toList();
  }

  Future<File> copyMarkerAsPhase({
    required String sourceName,
    required String targetName,
    required String phase,
    String? replacementMutationId,
  }) async {
    final source = File(
      '${installationRoot.path}${Platform.pathSeparator}$sourceName',
    );
    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw StateError('test_marker_json');
    }
    final payload = Map<String, Object?>.of(decoded)..remove('checksum');
    payload['phase'] = phase;
    if (replacementMutationId != null) {
      payload['mutationId'] = replacementMutationId;
    }
    final checksum = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();
    final target = File(
      '${installationRoot.path}${Platform.pathSeparator}$targetName',
    );
    await target.writeAsString(
      jsonEncode(<String, Object?>{...payload, 'checksum': checksum}),
      flush: true,
    );
    return target;
  }

  test('远端撤销确认后按安全顺序擦除安装数据并最后移除标记', () async {
    final events = <String>[];
    await writeInstallationFixture();

    final wipe = createWipe(
      applicationCacheDirectory: () async {
        expect(await installationRoot.exists(), isTrue);
        expect(
          (await installationEntities()).map((entity) => entity.path),
          everyElement(
            endsWith('.kelivo-local-wipe-v2.revocation-confirmed.json'),
          ),
        );
        return cacheRoot;
      },
      deleteAllSecureSlots: () async => events.add('secure-slots'),
      wipeInstallationRoot: ({required String preservedEntryName}) async {
        expect(
          preservedEntryName,
          LocalWipeMarkerTopology.revocationConfirmedMarkerFileName,
        );
        events.add('installation-root');
        await wipeInstallationRootForTest(
          preservedEntryName: preservedEntryName,
        );
      },
      clearAllPreferences: () async {
        expect(await installationRoot.exists(), isTrue);
        expect(
          (await installationEntities()).single.path,
          endsWith('.kelivo-local-wipe-v2.revocation-confirmed.json'),
        );
        await File(
          '${installationRoot.path}${Platform.pathSeparator}'
          'shared_preferences.json',
        ).writeAsString('{}', flush: true);
        events.add('preferences');
      },
    );

    await markConfirmed(wipe);
    expect(await wipe.hasPendingWipe(), isTrue);

    final resumed = await wipe.resumePendingAtColdStart(
      stopBackgroundSync: () async => events.add('background'),
    );

    expect(resumed, isTrue);
    expect(events, <String>[
      'background',
      'secure-slots',
      'installation-root',
      'preferences',
      'installation-root',
    ]);
    expect(await wipe.hasPendingWipe(), isFalse);
    expect(await installationRoot.list().toList(), isEmpty);
    expect(await cacheRoot.list().toList(), isEmpty);
  });

  test('没有已发布标记时保持安装数据且不执行任何步骤', () async {
    await writeInstallationFixture();
    final events = <String>[];
    final wipe = createWipe(
      applicationCacheDirectory: () async {
        events.add('cache');
        return cacheRoot;
      },
      deleteAllSecureSlots: () async => events.add('secure-slots'),
      clearAllPreferences: () async => events.add('preferences'),
    );

    expect(
      await wipe.resumePendingAtColdStart(
        stopBackgroundSync: () async => events.add('background'),
      ),
      isFalse,
    );

    expect(events, isEmpty);
    expect(await installationEntities(), isNotEmpty);
    expect(await cacheRoot.list().toList(), isNotEmpty);
  });

  test('原生 capability 不可用时在业务入口前拒绝且不写 marker', () async {
    final wipe = createWipe(isSupported: false);
    expect(wipe.isSupported, isFalse);

    await expectLater(
      wipe.markRevocationRequested(deviceId: deviceId, mutationId: mutationId),
      throwsA(isA<UnsupportedError>()),
    );
    expect(await installationEntities(), isEmpty);
  });

  test('confirmed marker 恢复时 capability 丢失则在清理密钥前失败关闭', () async {
    await markConfirmed(createWipe());
    final events = <String>[];
    final unsupportedWipe = createWipe(
      isSupported: false,
      deleteAllSecureSlots: () async => events.add('secure-slots'),
      wipeInstallationRoot: ({required String preservedEntryName}) async =>
          events.add('installation-root'),
      clearAllPreferences: () async => events.add('preferences'),
    );

    await expectLater(
      unsupportedWipe.resumePendingAtColdStart(
        stopBackgroundSync: () async => events.add('background'),
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(events, isEmpty);
    expect(await unsupportedWipe.hasPendingWipe(), isTrue);
  });

  test('原生安装根擦除失败时保留标记与数据并可从同一阶段重试', () async {
    await writeInstallationFixture();
    var failNextWipe = true;
    var wipeCalls = 0;
    final wipe = createWipe(
      wipeInstallationRoot: ({required String preservedEntryName}) async {
        wipeCalls += 1;
        if (failNextWipe) {
          failNextWipe = false;
          throw StateError('injected_installation_root_wipe');
        }
        await wipeInstallationRootForTest(
          preservedEntryName: preservedEntryName,
        );
      },
    );
    await markConfirmed(wipe);

    await expectLater(
      wipe.resumePendingAtColdStart(stopBackgroundSync: () async {}),
      throwsStateError,
    );
    expect(wipeCalls, 1);
    expect(await wipe.hasPendingWipe(), isTrue);
    expect(
      await File(
        '${installationRoot.path}${Platform.pathSeparator}account-a.db',
      ).exists(),
      isTrue,
    );

    expect(
      await wipe.resumePendingAtColdStart(stopBackgroundSync: () async {}),
      isTrue,
    );
    expect(wipeCalls, 3);
    expect(await wipe.hasPendingWipe(), isFalse);
  });

  test('原生谎报成功但留下数据时不得回退 Dart 删除或提交完成', () async {
    await writeInstallationFixture();
    var wipeCalls = 0;
    final wipe = createWipe(
      wipeInstallationRoot: ({required String preservedEntryName}) async {
        expect(
          preservedEntryName,
          LocalWipeMarkerTopology.revocationConfirmedMarkerFileName,
        );
        wipeCalls += 1;
      },
    );
    await markConfirmed(wipe);

    await expectLater(
      wipe.resumePendingAtColdStart(stopBackgroundSync: () async {}),
      throwsStateError,
    );
    expect(wipeCalls, 2);
    expect(await wipe.hasPendingWipe(), isTrue);
    expect(
      await File(
        '${installationRoot.path}${Platform.pathSeparator}account-a.db',
      ).exists(),
      isTrue,
    );
  });

  test('requested-only 冷启动只要求确认且不执行任何擦除步骤', () async {
    await writeInstallationFixture();
    final events = <String>[];
    final wipe = createWipe(
      applicationCacheDirectory: () async {
        events.add('cache');
        return cacheRoot;
      },
      deleteAllSecureSlots: () async => events.add('secure-slots'),
      clearAllPreferences: () async => events.add('preferences'),
    );
    await wipe.markRevocationRequested(
      deviceId: deviceId,
      mutationId: mutationId,
    );

    await expectLater(
      wipe.resumePendingAtColdStart(
        stopBackgroundSync: () async => events.add('background'),
      ),
      throwsA(
        isA<LocalDeviceRevocationConfirmationRequired>().having(
          (error) => error.intent.mutationId,
          'mutationId',
          mutationId,
        ),
      ),
    );

    expect(events, isEmpty);
    expect(await wipe.readPendingIntent(), isNotNull);
    expect(
      await File(
        '${installationRoot.path}${Platform.pathSeparator}account-a.db',
      ).exists(),
      isTrue,
    );
  });

  test('损坏标记失败关闭且不触发清理步骤', () async {
    await writeInstallationFixture();
    await File(
      '${installationRoot.path}${Platform.pathSeparator}'
      '.kelivo-local-wipe-v2.revocation-requested.json',
    ).writeAsString('{"format":"tampered"}', flush: true);
    final events = <String>[];
    final wipe = createWipe(
      deleteAllSecureSlots: () async => events.add('secure-slots'),
      clearAllPreferences: () async => events.add('preferences'),
    );

    await expectLater(
      wipe.resumePendingAtColdStart(
        stopBackgroundSync: () async => events.add('background'),
      ),
      throwsFormatException,
    );

    expect(events, isEmpty);
    expect(await installationEntities(), hasLength(3));
  });

  test('同一远端撤销回执可幂等发布，不同设备不得覆盖标记', () async {
    final wipe = createWipe();

    await markConfirmed(wipe);
    final firstMarker = (await installationEntities()).single as File;
    final firstBytes = await firstMarker.readAsBytes();
    await wipe.markRevocationRequested(
      deviceId: deviceId,
      mutationId: mutationId,
    );
    await wipe.markRevocationConfirmed(
      deviceId: deviceId,
      mutationId: mutationId,
    );

    final secondMarker = (await installationEntities()).single as File;
    expect(await secondMarker.readAsBytes(), firstBytes);
    await expectLater(
      wipe.markRevocationRequested(
        deviceId: otherDeviceId,
        mutationId: mutationId,
      ),
      throwsStateError,
    );
    expect(await wipe.hasPendingWipe(), isTrue);
  });

  test('requested 与 confirmed 同 intent 共存时收敛到 confirmed', () async {
    final wipe = createWipe();
    await wipe.markRevocationRequested(
      deviceId: deviceId,
      mutationId: mutationId,
    );
    await copyMarkerAsPhase(
      sourceName: LocalWipeMarkerTopology.revocationRequestedMarkerFileName,
      targetName: LocalWipeMarkerTopology.revocationConfirmedMarkerFileName,
      phase: 'revocation-confirmed',
    );

    final recovered = await wipe.readPendingIntent();

    expect(recovered?.phase, LocalCryptographicWipePhase.revocationConfirmed);
    expect(
      (await installationEntities()).single.path,
      endsWith(LocalWipeMarkerTopology.revocationConfirmedMarkerFileName),
    );
  });

  test('requested 与 confirmed 不同 intent 时失败关闭并保留证据', () async {
    final wipe = createWipe();
    await wipe.markRevocationRequested(
      deviceId: deviceId,
      mutationId: mutationId,
    );
    await copyMarkerAsPhase(
      sourceName: LocalWipeMarkerTopology.revocationRequestedMarkerFileName,
      targetName: LocalWipeMarkerTopology.revocationConfirmedMarkerFileName,
      phase: 'revocation-confirmed',
      replacementMutationId: otherDeviceId,
    );

    await expectLater(wipe.readPendingIntent(), throwsStateError);

    expect(await installationEntities(), hasLength(2));
  });

  test('requested 与 completion 共存属于非法跨阶段状态', () async {
    final wipe = createWipe();
    await wipe.markRevocationRequested(
      deviceId: deviceId,
      mutationId: mutationId,
    );
    await copyMarkerAsPhase(
      sourceName: LocalWipeMarkerTopology.revocationRequestedMarkerFileName,
      targetName: LocalWipeMarkerTopology.completionMarkerFileName,
      phase: 'completion',
    );

    await expectLater(wipe.readPendingIntent(), throwsStateError);

    expect(await installationEntities(), hasLength(2));
  });

  test('confirmed 临时文件可依据 requested 重建并收敛', () async {
    final wipe = createWipe();
    await wipe.markRevocationRequested(
      deviceId: deviceId,
      mutationId: mutationId,
    );
    final interrupted = createWipe(
      durability: _MemoryWipeDurability(failNextRename: true),
    );
    await expectLater(
      interrupted.markRevocationConfirmed(
        deviceId: deviceId,
        mutationId: mutationId,
      ),
      throwsStateError,
    );

    final recovered = await createWipe(
      durability: _MemoryWipeDurability(),
    ).readPendingIntent();

    expect(recovered?.phase, LocalCryptographicWipePhase.revocationConfirmed);
    expect(
      (await installationEntities()).single.path,
      endsWith(LocalWipeMarkerTopology.revocationConfirmedMarkerFileName),
    );
  });

  test('临时标记已落盘但未重命名时重启会恢复而非丢弃', () async {
    final interruptedDurability = _MemoryWipeDurability(failNextRename: true);
    final interrupted = createWipe(durability: interruptedDurability);

    await expectLater(
      interrupted.markRevocationRequested(
        deviceId: deviceId,
        mutationId: mutationId,
      ),
      throwsStateError,
    );
    expect((await installationEntities()).single.path, endsWith('.tmp'));

    final recovered = createWipe(durability: _MemoryWipeDurability());
    final recoveredIntent = await recovered.readPendingIntent();
    expect(
      recoveredIntent?.phase,
      LocalCryptographicWipePhase.revocationRequested,
    );
    expect(
      (await installationEntities()).single.path,
      endsWith('.kelivo-local-wipe-v2.revocation-requested.json'),
    );
    await expectLater(
      recovered.resumePendingAtColdStart(stopBackgroundSync: () async {}),
      throwsA(isA<LocalDeviceRevocationConfirmationRequired>()),
    );
    await recovered.markRevocationConfirmed(
      deviceId: deviceId,
      mutationId: mutationId,
    );
    expect(
      await recovered.resumePendingAtColdStart(stopBackgroundSync: () async {}),
      isTrue,
    );
    expect(await installationEntities(), isEmpty);
  });

  test('requested 临时标记只完成部分写入时永久失败关闭', () async {
    await File(
      '${installationRoot.path}${Platform.pathSeparator}'
      '.kelivo-local-wipe-v2.revocation-requested.json.1_1_0.tmp',
    ).writeAsString('{', flush: true);
    final wipe = createWipe(durability: _MemoryWipeDurability());

    await expectLater(wipe.readPendingIntent(), throwsFormatException);
    expect((await installationEntities()).single.path, endsWith('.tmp'));
  });

  test('最终标记删除后持久屏障失败时恢复标记并可重试', () async {
    final durability = _MarkerDeletionFailingDurability(installationRoot);
    final wipe = createWipe(durability: durability);
    await markConfirmed(wipe);

    await expectLater(
      wipe.resumePendingAtColdStart(stopBackgroundSync: () async {}),
      throwsStateError,
    );
    expect(await wipe.hasPendingWipe(), isTrue);

    expect(
      await wipe.resumePendingAtColdStart(stopBackgroundSync: () async {}),
      isTrue,
    );
    expect(await wipe.hasPendingWipe(), isFalse);
  });

  test('完成标记已发布后重启只收敛提交且不重复清理', () async {
    final events = <String>[];
    await writeInstallationFixture();
    final interrupted = createWipe(
      applicationCacheDirectory: () async {
        events.add('cache');
        return cacheRoot;
      },
      deleteAllSecureSlots: () async => events.add('secure-slots'),
      clearAllPreferences: () async => events.add('preferences'),
      durability: _CompletionCommitFailingDurability(installationRoot),
    );
    await markConfirmed(interrupted);

    await expectLater(
      interrupted.resumePendingAtColdStart(
        stopBackgroundSync: () async => events.add('background'),
      ),
      throwsStateError,
    );
    expect(
      (await installationEntities()).single.path,
      endsWith('.kelivo-local-wipe-v2.completed.json'),
    );
    expect(events, <String>[
      'background',
      'secure-slots',
      'preferences',
      'cache',
    ]);

    final recovered = createWipe(durability: _MemoryWipeDurability());
    expect(
      await recovered.resumePendingAtColdStart(
        stopBackgroundSync: () async => events.add('repeated-background'),
      ),
      isTrue,
    );
    expect(events, isNot(contains(startsWith('repeated-'))));
    expect(await installationEntities(), isEmpty);
  });

  for (final failingStep in <String>[
    'background',
    'secure-slots',
    'preferences',
    'cache',
  ]) {
    test('$failingStep 步骤失败时保留标记且重试只收敛本机清理', () async {
      await writeInstallationFixture();
      var shouldFail = true;

      Future<void> step(String name) async {
        if (shouldFail && name == failingStep) {
          throw StateError('injected_$name');
        }
      }

      final wipe = createWipe(
        applicationCacheDirectory: () async {
          await step('cache');
          return cacheRoot;
        },
        deleteAllSecureSlots: () => step('secure-slots'),
        clearAllPreferences: () => step('preferences'),
      );
      await markConfirmed(wipe);

      await expectLater(
        wipe.resumePendingAtColdStart(
          stopBackgroundSync: () => step('background'),
        ),
        throwsStateError,
      );
      expect(await wipe.hasPendingWipe(), isTrue);

      shouldFail = false;
      expect(
        await wipe.resumePendingAtColdStart(
          stopBackgroundSync: () => step('background'),
        ),
        isTrue,
      );
      expect(await wipe.hasPendingWipe(), isFalse);
      expect(await installationRoot.exists(), isTrue);
      expect(await installationEntities(), isEmpty);
    });
  }

  test('系统缓存若是安装根祖先则失败关闭且不得删除根外文件', () async {
    final outside = File(
      '${root.path}${Platform.pathSeparator}outside-recovery.kelivo',
    );
    await outside.writeAsString('user-export');
    await writeInstallationFixture();
    final wipe = createWipe(applicationCacheDirectory: () async => root);
    await markConfirmed(wipe);

    await expectLater(
      wipe.resumePendingAtColdStart(stopBackgroundSync: () async {}),
      throwsStateError,
    );

    expect(await wipe.hasPendingWipe(), isTrue);
    expect(await outside.readAsString(), 'user-export');
  });

  group('冷启动安装级准入', () {
    test('无 marker 时返回并持续持有 business lease', () async {
      final installationLease = InstallationOperationLease(
        installationRoot: installationRoot,
      );
      final startup = LocalCryptographicWipeStartupCoordinator(
        installationOperationLease: installationLease,
        localCryptographicWipe: createWipe(),
        stopBackgroundSync: () async {},
      );

      final admission = await startup.admit();

      expect(admission, isA<LocalCryptographicWipeBusinessReady>());
      final business =
          (admission as LocalCryptographicWipeBusinessReady).businessLease;
      expect(business.isClosed, isFalse);
      await business.close();
    });

    test('confirmed marker 在 EX 下完成后只允许冷重启', () async {
      final wipe = createWipe();
      await markConfirmed(wipe);
      final installationLease = InstallationOperationLease(
        installationRoot: installationRoot,
      );
      final startup = LocalCryptographicWipeStartupCoordinator(
        installationOperationLease: installationLease,
        localCryptographicWipe: wipe,
        stopBackgroundSync: () async {},
      );

      final admission = await startup.admit();

      expect(admission, isA<LocalCryptographicWipeRestartRequired>());
      expect(await wipe.hasPendingWipe(), isFalse);
      final business = await installationLease.acquireBusiness();
      await business.close();
    });

    test('marker 已删但 lease complete 失败时重试不重复擦除', () async {
      final marker = File(
        '${installationRoot.path}${Platform.pathSeparator}'
        '${LocalWipeMarkerTopology.revocationConfirmedMarkerFileName}',
      );
      await marker.writeAsString('{}', flush: true);
      final installationLease = InstallationOperationLease(
        installationRoot: installationRoot,
      );
      late final Directory blockingOwner;
      final wipe = _StartupTestWipe(
        installationRoot: installationRoot,
        afterResume: () async {
          final owner = File(
            '${installationLease.sidecarDirectory.path}'
            '${Platform.pathSeparator}.kelivo_business_lease'
            '${Platform.pathSeparator}owner_$pid',
          );
          await owner.delete();
          blockingOwner = Directory(owner.path);
          await blockingOwner.create();
        },
      );
      final startup = LocalCryptographicWipeStartupCoordinator(
        installationOperationLease: installationLease,
        localCryptographicWipe: wipe,
        stopBackgroundSync: () async {},
      );

      await expectLater(startup.admit(), throwsStateError);
      expect(wipe.resumeCalls, 1);
      expect(await marker.exists(), isFalse);

      await blockingOwner.delete();
      await startup.retryPendingWipe();
      expect(wipe.resumeCalls, 1);
      final business = await installationLease.acquireBusiness();
      await business.close();
    });

    test('requested-only 保持 EX 门禁直至同 mutation 得到确认', () async {
      final wipe = createWipe();
      await wipe.markRevocationRequested(
        deviceId: deviceId,
        mutationId: mutationId,
      );
      final installationLease = InstallationOperationLease(
        installationRoot: installationRoot,
      );
      final startup = LocalCryptographicWipeStartupCoordinator(
        installationOperationLease: installationLease,
        localCryptographicWipe: wipe,
        stopBackgroundSync: () async {},
      );

      await expectLater(
        startup.admit(),
        throwsA(isA<LocalDeviceRevocationConfirmationRequired>()),
      );
      await expectLater(
        InstallationOperationLease(
          installationRoot: installationRoot,
        ).acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );

      await wipe.markRevocationConfirmed(
        deviceId: deviceId,
        mutationId: mutationId,
      );
      await startup.retryPendingWipe();
      final business = await installationLease.acquireBusiness();
      await business.close();
    });
  });

  group('持久删除全部偏好', () {
    test('Apple 自有平台的原生耐久回执可直接完成擦除', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('kelivo.durable_preferences.test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final values = <String, Object>{
        'flutter.account': 'alice',
        'kelivo.account.alpha.secret': 'secret',
      };
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'initialize':
            return null;
          case 'get-all':
            return Map<String, Object>.from(values);
          case 'remove':
            final arguments = call.arguments as Map<Object?, Object?>;
            values.remove(arguments['key']);
            return null;
          default:
            fail('unexpected_method_${call.method}');
        }
      });
      final previousPlatform = SharedPreferencesStorePlatform.instance;
      try {
        final platform = KelivoDurablePreferences(channel: channel);
        await platform.initialize();
        SharedPreferencesStorePlatform.instance = platform;

        await const DurableSharedPreferencesEraser().eraseAll();

        expect(values, isEmpty);
      } finally {
        SharedPreferencesStorePlatform.instance = previousPlatform;
        messenger.setMockMethodCallHandler(channel, null);
      }
    });

    test('逐键删除全部原始键并复核为空', () async {
      final store = InMemorySharedPreferencesStore.withData(<String, Object>{
        'flutter.account': 'alice',
        'raw.installation-key': 'secret',
      });

      await DurableSharedPreferencesEraser(
        store: _createDurablePreferencesStore(store),
      ).eraseAll();

      expect(await _readAllRawPreferences(store), isEmpty);
    });

    test('空偏好库可幂等完成', () async {
      final store = InMemorySharedPreferencesStore.empty();

      await DurableSharedPreferencesEraser(
        store: _createDurablePreferencesStore(store),
      ).eraseAll();

      expect(await _readAllRawPreferences(store), isEmpty);
    });

    test('任一原始键删除回执为假时失败关闭', () async {
      final store = _RemoveRejectedPreferencesStore(<String, Object>{
        'flutter.account': 'alice',
      });

      await expectLater(
        DurableSharedPreferencesEraser(
          store: _createDurablePreferencesStore(store),
        ).eraseAll(),
        throwsStateError,
      );
      expect(await _readAllRawPreferences(store), isNotEmpty);
    });

    test('平台谎报删除成功但仍有残留时失败关闭', () async {
      final store = _ResidualPreferencesStore(<String, Object>{
        'flutter.account': 'alice',
      });

      await expectLater(
        DurableSharedPreferencesEraser(
          store: _createDurablePreferencesStore(store),
        ).eraseAll(),
        throwsStateError,
      );
      expect(await _readAllRawPreferences(store), isNotEmpty);
    });

    test('删除前固定证明会话并在复核后关闭', () async {
      final events = <String>[];
      final store = _RecordingPreferencesStore(<String, Object>{
        'flutter.account': 'alice',
      }, events);
      final proof = _RecordingSharedPreferencesRemovalProof(events);

      await PlatformDurableSharedPreferencesStore(
        store,
        removalProof: proof,
      ).remove('flutter.account');

      expect(events, <String>[
        'begin:flutter.account',
        'remove:flutter.account',
        'confirm',
        'read',
        'close',
      ]);
    });

    test('平台拒绝删除时仍关闭已固定的证明会话', () async {
      final events = <String>[];
      final store = _RecordingPreferencesStore(
        <String, Object>{'flutter.account': 'alice'},
        events,
        removeSucceeds: false,
      );
      final proof = _RecordingSharedPreferencesRemovalProof(events);

      await expectLater(
        PlatformDurableSharedPreferencesStore(
          store,
          removalProof: proof,
        ).remove('flutter.account'),
        throwsStateError,
      );

      expect(events, <String>[
        'begin:flutter.account',
        'remove:flutter.account',
        'close',
      ]);
    });

    test('复核与关闭同时失败时仍关闭且只暴露固定错误', () async {
      final events = <String>[];
      final store = _RecordingPreferencesStore(<String, Object>{
        'flutter.account': 'alice',
      }, events);
      final proof = _RecordingSharedPreferencesRemovalProof(
        events,
        confirmFails: true,
        closeFails: true,
      );

      await expectLater(
        PlatformDurableSharedPreferencesStore(
          store,
          removalProof: proof,
        ).remove('flutter.account'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            '固定错误',
            'durable_shared_preferences_operation_and_close_failed',
          ),
        ),
      );

      expect(events, <String>[
        'begin:flutter.account',
        'remove:flutter.account',
        'confirm',
        'close',
      ]);
    });

    test('非法或超限原始键不解析应用支持目录', () async {
      var directoryRequested = false;
      final proof = ManagedRootSharedPreferencesRemovalProof(
        applicationSupportDirectory: () async {
          directoryRequested = true;
          return root;
        },
      );

      await expectLater(
        proof.beginRemoval(List<String>.filled(342, '界').join()),
        throwsStateError,
      );
      await expectLater(
        proof.beginRemoval('flutter.\u0000unsafe'),
        throwsStateError,
      );

      expect(directoryRequested, isFalse);
    });
  });
}

PlatformDurableSharedPreferencesStore _createDurablePreferencesStore(
  SharedPreferencesStorePlatform platform,
) {
  return PlatformDurableSharedPreferencesStore(
    platform,
    removalProof: const _TestSharedPreferencesRemovalProof(),
  );
}

Future<Map<String, Object>> _readAllRawPreferences(
  SharedPreferencesStorePlatform store,
) {
  return store.getAllWithParameters(
    GetAllParameters(filter: PreferencesFilter(prefix: '')),
  );
}

final class _StartupTestWipe implements LocalCryptographicWipe {
  _StartupTestWipe({required this.installationRoot, required this.afterResume});

  final Directory installationRoot;
  final Future<void> Function() afterResume;
  int resumeCalls = 0;

  File get _marker => File(
    '${installationRoot.path}${Platform.pathSeparator}'
    '${LocalWipeMarkerTopology.revocationConfirmedMarkerFileName}',
  );

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasPendingWipe() => _marker.exists();

  @override
  Future<void> markRevocationConfirmed({
    required String deviceId,
    required String mutationId,
  }) {
    throw UnsupportedError('startup_test_wipe_mark_confirmed');
  }

  @override
  Future<void> markRevocationRequested({
    required String deviceId,
    required String mutationId,
  }) {
    throw UnsupportedError('startup_test_wipe_mark_requested');
  }

  @override
  Future<LocalCryptographicWipeIntent?> readPendingIntent() async {
    if (!await _marker.exists()) return null;
    return LocalCryptographicWipeIntent(
      phase: LocalCryptographicWipePhase.revocationConfirmed,
      deviceId: '00000000-0000-4000-8000-000000000001',
      mutationId: '00000000-0000-4000-8000-000000000003',
      createdAtUtc: DateTime.utc(2026, 8),
    );
  }

  @override
  Future<bool> resumePendingAtColdStart({
    required LocalCryptographicWipeStep stopBackgroundSync,
  }) async {
    if (!await _marker.exists()) return false;
    resumeCalls++;
    await stopBackgroundSync();
    await _marker.delete();
    await afterResume();
    return true;
  }
}

final class _RemoveRejectedPreferencesStore
    extends InMemorySharedPreferencesStore {
  _RemoveRejectedPreferencesStore(super.data) : super.withData();

  @override
  Future<bool> remove(String key) async => false;
}

final class _ResidualPreferencesStore extends InMemorySharedPreferencesStore {
  _ResidualPreferencesStore(super.data) : super.withData();

  @override
  Future<bool> remove(String key) async => true;
}

final class _RecordingPreferencesStore extends InMemorySharedPreferencesStore {
  _RecordingPreferencesStore(
    super.data,
    this.events, {
    this.removeSucceeds = true,
  }) : super.withData();

  final List<String> events;
  final bool removeSucceeds;

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    events.add('read');
    return super.getAllWithParameters(parameters);
  }

  @override
  Future<bool> remove(String key) async {
    events.add('remove:$key');
    if (!removeSucceeds) return false;
    return super.remove(key);
  }
}

final class _RecordingSharedPreferencesRemovalProof
    implements DurableSharedPreferencesRemovalProof {
  _RecordingSharedPreferencesRemovalProof(
    this.events, {
    this.confirmFails = false,
    this.closeFails = false,
  });

  final List<String> events;
  final bool confirmFails;
  final bool closeFails;

  @override
  Future<DurableSharedPreferencesRemovalSession> beginRemoval(
    String rawKey,
  ) async {
    events.add('begin:$rawKey');
    return _RecordingSharedPreferencesRemovalSession(
      events,
      confirmFails: confirmFails,
      closeFails: closeFails,
    );
  }
}

final class _RecordingSharedPreferencesRemovalSession
    implements DurableSharedPreferencesRemovalSession {
  _RecordingSharedPreferencesRemovalSession(
    this.events, {
    required this.confirmFails,
    required this.closeFails,
  });

  final List<String> events;
  final bool confirmFails;
  final bool closeFails;

  @override
  Future<void> confirmRemoval() async {
    events.add('confirm');
    if (confirmFails) throw StateError('injected_confirm_failure');
  }

  @override
  Future<void> close() async {
    events.add('close');
    if (closeFails) throw StateError('injected_close_failure');
  }
}

final class _TestSharedPreferencesRemovalProof
    implements DurableSharedPreferencesRemovalProof {
  const _TestSharedPreferencesRemovalProof();

  @override
  Future<DurableSharedPreferencesRemovalSession> beginRemoval(
    String rawKey,
  ) async => const _TestSharedPreferencesRemovalSession();
}

final class _TestSharedPreferencesRemovalSession
    implements DurableSharedPreferencesRemovalSession {
  const _TestSharedPreferencesRemovalSession();

  @override
  Future<void> confirmRemoval() async {}

  @override
  Future<void> close() async {}
}

class _MemoryWipeDurability implements RestoreDurability {
  _MemoryWipeDurability({this.failNextRename = false});

  bool failNextRename;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    if (failNextRename) {
      failNextRename = false;
      throw StateError('injected_rename_failure');
    }
    final type = await FileSystemEntity.type(source.path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.file:
        await File(source.path).rename(targetPath);
        return;
      case FileSystemEntityType.directory:
        await Directory(source.path).rename(targetPath);
        return;
      default:
        throw StateError('injected_rename_source_type');
    }
  }

  @override
  Future<void> restrictDirectory(Directory directory) async {}

  @override
  Future<void> restrictFile(File file) async {}

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {}

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {}
}

final class _MarkerDeletionFailingDurability extends _MemoryWipeDurability {
  _MarkerDeletionFailingDurability(this.installationRoot);

  final Directory installationRoot;
  bool _failed = false;

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    if (!_failed &&
        directory.path == installationRoot.path &&
        await directory.list(followLinks: false).isEmpty) {
      _failed = true;
      throw StateError('injected_marker_directory_sync_failure');
    }
  }
}

final class _CompletionCommitFailingDurability extends _MemoryWipeDurability {
  _CompletionCommitFailingDurability(this.installationRoot);

  final Directory installationRoot;
  bool _failed = false;

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    if (_failed || directory.path != installationRoot.path) return;
    final retained = await directory.list(followLinks: false).toList();
    if (retained.length == 1 &&
        retained.single.path.endsWith('.kelivo-local-wipe-v2.completed.json')) {
      _failed = true;
      throw StateError('injected_completion_commit_failure');
    }
  }
}
