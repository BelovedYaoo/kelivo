import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:Kelivo/core/services/sync/e2ee_background_sync_runner.dart';
import 'package:Kelivo/core/services/workspace/installation_operation_lease.dart';
import 'package:Kelivo/core/services/workspace/local_wipe_marker_topology.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('InstallationOperationLease', () {
    late Directory temporaryRoot;
    late Directory installationRoot;
    late InstallationOperationLease coordinator;

    setUp(() async {
      temporaryRoot = await Directory.systemTemp.createTemp(
        'kelivo_installation_operation_lease_',
      );
      installationRoot = Directory(p.join(temporaryRoot.path, 'installation'));
      await installationRoot.create();
      coordinator = InstallationOperationLease(
        installationRoot: installationRoot,
      );
    });

    tearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });

    test('business 在 turnstile 内复核 requested 与 completion marker', () async {
      final activeMarker = File(
        p.join(
          installationRoot.path,
          LocalWipeMarkerTopology.revocationRequestedMarkerFileName,
        ),
      );
      await activeMarker.writeAsString('{}', flush: true);

      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );

      await activeMarker.delete();
      final completionMarker = File(
        p.join(
          installationRoot.path,
          LocalWipeMarkerTopology.completionMarkerFileName,
        ),
      );
      await completionMarker.writeAsString('{}', flush: true);

      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );
    });

    test('temp-only cold-start 取得 exclusive 且 business 被拒绝', () async {
      final temporaryMarker = File(
        p.join(
          installationRoot.path,
          '.kelivo-local-wipe-v2.revocation-requested.json.1_2_3.tmp',
        ),
      );
      await temporaryMarker.writeAsString('{}', flush: true);

      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );
      final wipe = await coordinator.acquirePendingWipe();

      expect(wipe, isNotNull);
      expect(wipe!.isExclusive, isTrue);
      await temporaryMarker.delete();
      await wipe.complete();
    });

    test('保留前缀下的非法 temp 名字失败关闭', () async {
      await File(
        p.join(
          installationRoot.path,
          '.kelivo-local-wipe-v2.revocation-requested.json.invalid.tmp',
        ),
      ).writeAsString('{}');

      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<StateError>()),
      );
    });

    test('begin 等待 business owner 发布并在 requested 后排空', () async {
      final ownerPublishing = Completer<void>();
      final allowOwnerPublish = Completer<void>();
      coordinator = InstallationOperationLease.forTesting(
        installationRoot: installationRoot,
        platform: _supportedTestPlatform(),
        beforeBusinessOwnerPublish: () async {
          ownerPublishing.complete();
          await allowOwnerPublish.future;
        },
      );
      final businessAcquisition = coordinator.acquireBusiness();
      await ownerPublishing.future;

      var intentAcquired = false;
      final intentAcquisition = coordinator.beginRevocationRequest().then((
        value,
      ) {
        intentAcquired = true;
        return value;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(intentAcquired, isFalse);

      allowOwnerPublish.complete();
      final business = await businessAcquisition;
      final intent = await intentAcquisition.timeout(
        const Duration(seconds: 5),
      );
      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );

      final requested = await _publishRequestedMarker(installationRoot);
      var drained = false;
      final drain = intent.drainBusinessAfterRequestedPublished().then((_) {
        drained = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(drained, isFalse);

      await business.close();
      await drain.timeout(const Duration(seconds: 5));
      expect(intent.isExclusive, isTrue);
      final wipe = await coordinator.acquirePendingWipe();
      await expectLater(wipe!.complete(), throwsA(isA<StateError>()));
      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );

      await requested.delete();
      final confirmed = await _publishConfirmedMarker(installationRoot);
      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );
      expect(wipe.isExclusive, isTrue);
      await confirmed.delete();
      await wipe.complete();
    });

    test('requested 发布失败后 intent 仍持续阻断业务', () async {
      final intent = await coordinator.beginRevocationRequest();

      await expectLater(
        intent.drainBusinessAfterRequestedPublished(),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );
      await expectLater(
        coordinator.acquirePendingWipe(),
        throwsA(isA<StateError>()),
      );

      final requested = await _publishRequestedMarker(installationRoot);
      await intent.drainBusinessAfterRequestedPublished();
      final wipe = await coordinator.acquirePendingWipe();
      await requested.delete();
      await wipe!.complete();
    });

    test('已有 business 释放前 wipe 不能进入 exclusive', () async {
      final business = await coordinator.acquireBusiness();
      final marker = await _publishConfirmedMarker(installationRoot);

      var exclusiveAcquired = false;
      InstallationWipeLease? wipe;
      final acquisition = coordinator.acquirePendingWipe().then((value) {
        wipe = value;
        exclusiveAcquired = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(exclusiveAcquired, isFalse);

      await business.close();
      await acquisition.timeout(const Duration(seconds: 5));
      expect(wipe, isNotNull);
      expect(wipe!.isExclusive, isTrue);

      await marker.delete();
      await wipe!.complete();
      expect(wipe!.isClosed, isTrue);
    });

    test('wipe turnstile 持有期间禁止新 business', () async {
      final marker = await _publishConfirmedMarker(installationRoot);
      final wipe = await coordinator.acquirePendingWipe();

      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );

      await marker.delete();
      await wipe!.complete();
    });

    test('completion marker 未清除时不能释放 exclusive', () async {
      final marker = await _publishConfirmedMarker(installationRoot);
      final wipe = await coordinator.acquirePendingWipe();

      await expectLater(wipe!.complete(), throwsA(isA<StateError>()));
      expect(wipe.isExclusive, isTrue);
      expect(wipe.isClosed, isFalse);
      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );

      await marker.delete();
      await wipe.complete();
    });

    test('cold-start 仅在 marker 存在时取得 pending wipe exclusive', () async {
      expect(await coordinator.acquirePendingWipe(), isNull);
      final business = await coordinator.acquireBusiness();
      await business.close();

      final marker = await _publishConfirmedMarker(installationRoot);
      final wipe = await coordinator.acquirePendingWipe();

      expect(wipe, isNotNull);
      expect(wipe!.isExclusive, isTrue);
      await marker.delete();
      await wipe.complete();
    });

    test('business owner 删除失败后 close 可继续重试收敛', () async {
      final business = await coordinator.acquireBusiness();
      final activity = Directory(
        p.join(coordinator.sidecarDirectory.path, 'activity'),
      );
      final owner = await activity
          .list(followLinks: false)
          .where((entity) => p.basename(entity.path).startsWith('owner_'))
          .single;
      await owner.delete();
      final blockingDirectory = Directory(owner.path);
      await blockingDirectory.create();

      await expectLater(business.close(), throwsA(isA<StateError>()));
      expect(business.isClosed, isFalse);

      await blockingDirectory.delete();
      await business.close();
      expect(business.isClosed, isTrue);
    });

    test('wipe turnstile 清理失败后 complete 可继续重试收敛', () async {
      final marker = await _publishConfirmedMarker(installationRoot);
      final wipe = await coordinator.acquirePendingWipe();
      final turnstileOwner = File(
        p.join(
          coordinator.sidecarDirectory.path,
          '.kelivo_business_lease',
          'owner_$pid',
        ),
      );
      await turnstileOwner.delete();
      final blockingDirectory = Directory(turnstileOwner.path);
      await blockingDirectory.create();
      await marker.delete();

      await expectLater(wipe!.complete(), throwsA(isA<StateError>()));
      expect(wipe.isClosed, isFalse);

      await blockingDirectory.delete();
      await wipe.complete();
      expect(wipe.isClosed, isTrue);
    });

    test('exclusive 获取失败时保留 turnstile 并允许修复后重试', () async {
      expect(await coordinator.acquirePendingWipe(), isNull);
      final marker = await _publishConfirmedMarker(installationRoot);
      await Directory(
        p.join(coordinator.sidecarDirectory.path, 'activity'),
      ).create();
      final unexpected = File(
        p.join(coordinator.sidecarDirectory.path, 'activity', 'unexpected'),
      );
      await unexpected.writeAsString('unsafe');

      await expectLater(
        coordinator.acquirePendingWipe(),
        throwsA(isA<StateError>()),
      );
      await marker.delete();
      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<InstallationBusinessLeaseUnavailable>()),
      );

      await _publishConfirmedMarker(installationRoot);
      await unexpected.delete();
      final retried = await coordinator.acquirePendingWipe();
      expect(retried!.isExclusive, isTrue);
      await File(
        p.join(
          installationRoot.path,
          LocalWipeMarkerTopology.revocationConfirmedMarkerFileName,
        ),
      ).delete();
      await retried.complete();
    });

    test('同进程其他 isolate 的 business 释放前 wipe 保持等待', () async {
      final ready = ReceivePort();
      final isolate = await Isolate.spawn(_holdBusinessLease, (
        installationRoot.path,
        ready.sendPort,
      ));
      addTearDown(() {
        ready.close();
        isolate.kill(priority: Isolate.immediate);
      });
      final releasePort = await ready.first as SendPort;

      final intent = await coordinator.beginRevocationRequest();
      final marker = await _publishRequestedMarker(installationRoot);
      var exclusiveAcquired = false;
      final acquisition = intent.drainBusinessAfterRequestedPublished().then((
        _,
      ) {
        exclusiveAcquired = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(exclusiveAcquired, isFalse);

      releasePort.send(null);
      await acquisition.timeout(const Duration(seconds: 5));
      final wipe = await coordinator.acquirePendingWipe();
      await marker.delete();
      await wipe!.complete();
    });

    test('其他进程的 business 释放前 wipe 保持等待', () async {
      final helperParent = Directory(
        p.join(Directory.current.path, '.dart_tool'),
      );
      await helperParent.create(recursive: true);
      final helperRoot = await helperParent.createTemp(
        'kelivo_installation_operation_lease_helper_',
      );
      addTearDown(() async {
        if (await helperRoot.exists()) {
          await helperRoot.delete(recursive: true);
        }
      });
      final helper = File(p.join(helperRoot.path, 'business_helper.dart'));
      await helper.writeAsString(_helperSource, flush: true);
      final packageConfig = p.join(
        Directory.current.path,
        '.dart_tool',
        'package_config.json',
      );
      final releaseFile = File(p.join(temporaryRoot.path, 'release_helper'));
      final process = await Process.start(_dartExecutable(), <String>[
        '--packages=$packageConfig',
        helper.path,
        installationRoot.path,
        releaseFile.path,
      ], workingDirectory: Directory.current.path);
      addTearDown(() async {
        process.kill();
        await process.stdin.close();
      });
      final stderr = process.stderr.transform(utf8.decoder).join();
      final ready = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 15));
      if (ready != 'ready') {
        throw StateError('business helper failed: ${await stderr}');
      }

      final intent = await coordinator.beginRevocationRequest();
      final marker = await _publishRequestedMarker(installationRoot);
      var exclusiveAcquired = false;
      final acquisition = intent.drainBusinessAfterRequestedPublished().then((
        _,
      ) {
        exclusiveAcquired = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(exclusiveAcquired, isFalse);

      await releaseFile.writeAsString('release', flush: true);
      await process.exitCode.timeout(const Duration(seconds: 15));
      await acquisition.timeout(const Duration(seconds: 5));
      final wipe = await coordinator.acquirePendingWipe();
      await marker.delete();
      await wipe!.complete();
    });

    test('其他进程崩溃后 cold pending 回收陈旧 owner', () async {
      final helperParent = Directory(
        p.join(Directory.current.path, '.dart_tool'),
      );
      await helperParent.create(recursive: true);
      final helperRoot = await helperParent.createTemp(
        'kelivo_installation_operation_lease_crash_helper_',
      );
      addTearDown(() async {
        if (await helperRoot.exists()) {
          await helperRoot.delete(recursive: true);
        }
      });
      final helper = File(p.join(helperRoot.path, 'business_helper.dart'));
      await helper.writeAsString(_helperSource, flush: true);
      final packageConfig = p.join(
        Directory.current.path,
        '.dart_tool',
        'package_config.json',
      );
      final neverRelease = File(
        p.join(temporaryRoot.path, 'never_release_helper'),
      );
      final process = await Process.start(_dartExecutable(), <String>[
        '--packages=$packageConfig',
        helper.path,
        installationRoot.path,
        neverRelease.path,
      ], workingDirectory: Directory.current.path);
      addTearDown(() async {
        process.kill();
        await process.stdin.close();
      });
      final stderr = process.stderr.transform(utf8.decoder).join();
      final ready = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 15));
      if (ready != 'ready') {
        throw StateError('business crash helper failed: ${await stderr}');
      }

      final marker = await _publishConfirmedMarker(installationRoot);
      expect(process.kill(), isTrue);
      await process.exitCode.timeout(const Duration(seconds: 15));

      final wipe = await coordinator.acquirePendingWipe().timeout(
        const Duration(seconds: 5),
      );

      expect(wipe, isNotNull);
      expect(wipe!.isExclusive, isTrue);
      final ownerFiles =
          await Directory(
            p.join(coordinator.sidecarDirectory.path, 'activity'),
          ).list(followLinks: false).where((entity) {
            return p.basename(entity.path).startsWith('owner_');
          }).toList();
      expect(ownerFiles, isEmpty);
      await marker.delete();
      await wipe.complete();
    });

    test('sidecar 固定路径若不是目录则失败关闭', () async {
      await File(coordinator.sidecarDirectory.path).writeAsString('blocked');

      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<StateError>()),
      );
    });

    test('sidecar 为链接时失败关闭', () async {
      final target = Directory(p.join(temporaryRoot.path, 'sidecar-target'));
      await target.create();
      await Link(coordinator.sidecarDirectory.path).create(target.path);

      await expectLater(
        coordinator.acquireBusiness(),
        throwsA(isA<StateError>()),
      );
    }, skip: Platform.isWindows ? 'Windows 创建符号链接需要额外权限。' : false);

    test('Apple 平台显式失败关闭', () async {
      final appleCoordinator = InstallationOperationLease.forTesting(
        installationRoot: installationRoot,
        platform: InstallationOperationLeasePlatform.apple,
      );

      final business = await appleCoordinator.acquireBusiness();
      expect(business.isClosed, isTrue);
      expect(await appleCoordinator.acquirePendingWipe(), isNull);

      await _publishConfirmedMarker(installationRoot);
      await expectLater(
        appleCoordinator.acquireBusiness(),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        appleCoordinator.acquirePendingWipe(),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('后台 runner 在 marker 已发布时不进入 workspace', () async {
      await _publishConfirmedMarker(installationRoot);
      final runner = E2eeBackgroundSyncRunner(
        installationRoot: installationRoot,
      );

      final outcome = await runner.run();

      expect(outcome.disposition, E2eeBackgroundSyncDisposition.workspaceBusy);
    });
  });
}

Future<File> _publishConfirmedMarker(Directory installationRoot) async {
  final marker = File(
    p.join(
      installationRoot.path,
      LocalWipeMarkerTopology.revocationConfirmedMarkerFileName,
    ),
  );
  await marker.writeAsString('{}', flush: true);
  return marker;
}

Future<File> _publishRequestedMarker(Directory installationRoot) async {
  final marker = File(
    p.join(
      installationRoot.path,
      LocalWipeMarkerTopology.revocationRequestedMarkerFileName,
    ),
  );
  await marker.writeAsString('{}', flush: true);
  return marker;
}

InstallationOperationLeasePlatform _supportedTestPlatform() {
  if (Platform.isWindows) return InstallationOperationLeasePlatform.windows;
  if (Platform.isLinux) return InstallationOperationLeasePlatform.linux;
  return InstallationOperationLeasePlatform.android;
}

Future<void> _holdBusinessLease((String, SendPort) message) async {
  final (installationRootPath, ready) = message;
  final lease = await InstallationOperationLease(
    installationRoot: Directory(installationRootPath),
  ).acquireBusiness();
  final release = ReceivePort();
  ready.send(release.sendPort);
  await release.first;
  release.close();
  await lease.close();
}

String _dartExecutable() {
  final executableName = Platform.isWindows ? 'dart.exe' : 'dart';
  final resolved = File(Platform.resolvedExecutable);
  if (p.basename(resolved.path).toLowerCase() == executableName) {
    return resolved.path;
  }

  var current = resolved.parent;
  while (!p.equals(current.path, current.parent.path)) {
    final candidate = File(
      p.join(current.path, 'bin', 'cache', 'dart-sdk', 'bin', executableName),
    );
    if (candidate.existsSync()) return candidate.path;
    current = current.parent;
  }
  throw StateError('dart_sdk_executable_not_found');
}

const _helperSource = r'''
import 'dart:io';

import 'package:Kelivo/core/services/workspace/installation_operation_lease.dart';

Future<void> main(List<String> arguments) async {
  final lease = await InstallationOperationLease(
    installationRoot: Directory(arguments[0]),
  ).acquireBusiness();
  stdout.writeln('ready');
  await stdout.flush();
  final releaseFile = File(arguments[1]);
  while (!await releaseFile.exists()) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await lease.close();
}
''';
