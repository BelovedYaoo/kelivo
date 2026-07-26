import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/models/provider_group.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_state_retirement.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/core/services/workspace/account_session_token_store.dart';
import 'package:Kelivo/core/services/workspace/account_workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Future<AccountWorkspaceRuntime> bootstrap({
    DateTime Function()? utcNow,
  }) async {
    final runtime = await AccountWorkspaceRuntime.bootstrap(
      installationRoot: installationRoot,
      sessionTokenStore: sessionTokenStore,
      utcNow: utcNow,
    );
    runtimes.add(runtime);
    return runtime;
  }

  Future<void> close(AccountWorkspaceRuntime runtime) async {
    await runtime.close();
    runtimes.remove(runtime);
  }

  Future<void> mutateStoredSessionMetadata(
    CloudSyncAccountSession session,
    void Function(Map<String, Object?> metadata) mutate,
  ) async {
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
    final sessionRecords = await accountDirectory
        .list(followLinks: false)
        .where(
          (entity) =>
              entity is File &&
              p.basename(entity.path).startsWith('session-v2-'),
        )
        .cast<File>()
        .toList();
    expect(sessionRecords, hasLength(1));
    final record =
        jsonDecode(await sessionRecords.single.readAsString())
            as Map<String, Object?>;
    final payload = record['payload'] as Map<String, Object?>;
    final metadata = payload['session'] as Map<String, Object?>;
    mutate(metadata);
    await sessionRecords.single.writeAsString(jsonEncode(record), flush: true);
  }

  Future<void> expectStoredSessionMetadataRejected(
    void Function(Map<String, Object?> metadata) mutate,
  ) async {
    final session = _session(
      userId: 'account-a',
      token: 'metadata-validation-token',
    );
    final runtime = await bootstrap();
    await runtime.bindAccount(session);
    await close(runtime);
    await mutateStoredSessionMetadata(session, mutate);

    await expectLater(bootstrap(), throwsA(isA<FormatException>()));
  }

  test('设备状态首次发布后可按规范身份读取且路径不泄漏登录名', () async {
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    const baseUrl = 'https://kelivo.bemylover.top';
    const loginName = 'alice.private@example.com';
    final state = Uint8List.fromList(
      List<int>.generate(188, (index) => index & 0xff),
    );

    expect(
      await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );

    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: state,
    );

    expect(
      await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      orderedEquals(state),
    );
    final persistedPaths = await installationRoot
        .list(recursive: true, followLinks: false)
        .map((entity) => entity.path.toLowerCase())
        .toList();
    expect(persistedPaths.where((path) => path.contains(loginName)), isEmpty);
    final locator = await _deviceStateLocatorDirectory(
      installationRoot,
      expectedCount: 1,
    );
    expect(
      p.basename(locator.path),
      'effefc01e7293e432584e2ea8cef7f7c816bc0daeaa0b6a97856248d7d58da0b',
    );
  });

  test('首设备注册事务信封只允许原样重放并按摘要确认删除', () async {
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    const baseUrl = 'https://kelivo.bemylover.top';
    const loginName = 'pending-registration';
    final state = Uint8List(DeviceStateBlobStore.blobLength)
      ..fillRange(0, DeviceStateBlobStore.blobLength, 0x31);
    final envelope = Uint8List.fromList(
      List<int>.generate(257, (index) => (index * 17) & 0xff),
    );
    final digest = Uint8List.fromList(sha256.convert(envelope).bytes);
    await expectLater(
      store.writePendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        envelope: envelope,
      ),
      throwsA(isA<StateError>()),
    );
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: state,
    );
    expect(
      () => store.writePendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        envelope: Uint8List(0),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => store.writePendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        envelope: Uint8List(
          DeviceStateBlobStore.pendingRegistrationEnvelopeMaxLength + 1,
        ),
      ),
      throwsA(isA<FormatException>()),
    );

    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );
    await store.writePendingRegistrationEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: envelope,
    );
    await store.writePendingRegistrationEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: Uint8List.fromList(envelope),
    );

    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      orderedEquals(envelope),
    );
    await expectLater(
      store.writePendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        envelope: Uint8List.fromList(envelope)..last ^= 1,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.deletePendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        expectedDigest: Uint8List(32)..fillRange(0, 32, 0x44),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => store.deletePendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        expectedDigest: Uint8List(31),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      await store.deletePendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        expectedDigest: digest,
      ),
      isTrue,
    );
    expect(
      await store.deletePendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        expectedDigest: digest,
      ),
      isFalse,
    );
  });

  test('首设备注册事务重命名后屏障中断仍可由新实例原样恢复', () async {
    const baseUrl = 'https://kelivo.bemylover.top';
    const loginName = 'registration-publish-interrupted';
    final normalStore = DeviceStateBlobStore(
      installationRoot: installationRoot,
    );
    await normalStore.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: Uint8List(DeviceStateBlobStore.blobLength)
        ..fillRange(0, DeviceStateBlobStore.blobLength, 0x46),
    );
    final envelope = Uint8List(320)..fillRange(0, 320, 0x47);
    final interruptedStore = DeviceStateBlobStore(
      installationRoot: installationRoot,
      durability: _InterruptAfterPendingRegistrationRenameDurability(
        RestorePlatformDurability(),
      ),
    );

    await expectLater(
      interruptedStore.writePendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        envelope: envelope,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await DeviceStateBlobStore(
        installationRoot: installationRoot,
      ).readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      orderedEquals(envelope),
    );
    await normalStore.writePendingRegistrationEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: envelope,
    );
  });

  test('首设备注册事务损坏时失败关闭且设备删除一并退役事务', () async {
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    const baseUrl = 'https://kelivo.bemylover.top';
    const loginName = 'damaged-registration';
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: Uint8List(DeviceStateBlobStore.blobLength)
        ..fillRange(0, DeviceStateBlobStore.blobLength, 0x32),
    );
    await store.writePendingRegistrationEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: Uint8List(128)..fillRange(0, 128, 0x45),
    );
    final locator = await _deviceStateLocatorDirectory(
      installationRoot,
      expectedCount: 1,
    );
    final pendingFile = File(p.join(locator.path, 'registration-pending.bin'));
    final damaged = await pendingFile.readAsBytes()
      ..last ^= 1;
    await pendingFile.writeAsBytes(damaged, flush: true);

    await expectLater(
      store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      throwsA(isA<FormatException>()),
    );
    await store.delete(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
    );
    expect(await pendingFile.exists(), isFalse);
    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );
  });

  test('设备配对事务信封只允许原样重放并按摘要确认删除', () async {
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    const baseUrl = 'https://kelivo.bemylover.top';
    const loginName = 'pending-pairing';
    final envelope = Uint8List.fromList(
      List<int>.generate(513, (index) => (index * 29) & 0xff),
    );
    final digest = Uint8List.fromList(sha256.convert(envelope).bytes);

    await expectLater(
      store.writePendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        envelope: envelope,
      ),
      throwsA(isA<StateError>()),
    );
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: Uint8List(DeviceStateBlobStore.blobLength)
        ..fillRange(0, DeviceStateBlobStore.blobLength, 0x51),
    );
    expect(
      () => store.writePendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        envelope: Uint8List(0),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => store.writePendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        envelope: Uint8List(
          DeviceStateBlobStore.pendingPairingEnvelopeMaxLength + 1,
        ),
      ),
      throwsA(isA<FormatException>()),
    );

    await store.writePendingPairingEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: envelope,
    );
    await store.writePendingPairingEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: Uint8List.fromList(envelope),
    );
    expect(
      await store.readPendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      orderedEquals(envelope),
    );
    await expectLater(
      store.writePendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        envelope: Uint8List.fromList(envelope)..first ^= 1,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.deletePendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        expectedDigest: Uint8List(32)..fillRange(0, 32, 0x52),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await store.deletePendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        expectedDigest: digest,
      ),
      isTrue,
    );
    expect(
      await store.deletePendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        expectedDigest: digest,
      ),
      isFalse,
    );
  });

  test('设备配对事务重命名后屏障中断仍可由新实例原样恢复', () async {
    const baseUrl = 'https://kelivo.bemylover.top';
    const loginName = 'pairing-publish-interrupted';
    final normalStore = DeviceStateBlobStore(
      installationRoot: installationRoot,
    );
    await normalStore.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: Uint8List(DeviceStateBlobStore.blobLength)
        ..fillRange(0, DeviceStateBlobStore.blobLength, 0x53),
    );
    final envelope = Uint8List(384)..fillRange(0, 384, 0x54);
    final interruptedStore = DeviceStateBlobStore(
      installationRoot: installationRoot,
      durability: _InterruptAfterPendingPairingRenameDurability(
        RestorePlatformDurability(),
      ),
    );

    await expectLater(
      interruptedStore.writePendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        envelope: envelope,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await DeviceStateBlobStore(
        installationRoot: installationRoot,
      ).readPendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      orderedEquals(envelope),
    );
    await normalStore.writePendingPairingEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: envelope,
    );
  });

  test('设备配对事务损坏时失败关闭且设备删除一并退役事务', () async {
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    const baseUrl = 'https://kelivo.bemylover.top';
    const loginName = 'damaged-pairing';
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: Uint8List(DeviceStateBlobStore.blobLength)
        ..fillRange(0, DeviceStateBlobStore.blobLength, 0x55),
    );
    await store.writePendingPairingEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: Uint8List(192)..fillRange(0, 192, 0x56),
    );
    final locator = await _deviceStateLocatorDirectory(
      installationRoot,
      expectedCount: 1,
    );
    final pendingFile = File(p.join(locator.path, 'pairing-pending.bin'));
    final damaged = await pendingFile.readAsBytes()
      ..last ^= 1;
    await pendingFile.writeAsBytes(damaged, flush: true);

    await expectLater(
      store.readPendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      throwsA(isA<FormatException>()),
    );
    await store.delete(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
    );
    expect(await pendingFile.exists(), isFalse);
    expect(
      await store.readPendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );
  });

  test('设备状态删除只清理指定身份且删除后与损坏严格区分', () async {
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    final first = Uint8List(188)..fillRange(0, 188, 0x11);
    final second = Uint8List(188)..fillRange(0, 188, 0x22);
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'alice',
      blob: first,
    );
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'bob',
      blob: second,
    );

    await store.delete(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'alice',
    );

    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'alice',
      ),
      isNull,
    );
    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'bob',
      ),
      orderedEquals(second),
    );
  });

  test('设备状态删除发布tombstone后遇路径异常仍不得复活', () async {
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    final state = Uint8List(188)..fillRange(0, 188, 0x23);
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'unsafe-delete',
      blob: state,
    );
    final locator = await _deviceStateLocatorDirectory(
      installationRoot,
      expectedCount: 1,
    );
    final unexpectedDirectory = Directory(p.join(locator.path, 'state-b.bin'));
    await unexpectedDirectory.create();

    await expectLater(
      store.delete(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'unsafe-delete',
      ),
      throwsA(isA<StateError>()),
    );
    await unexpectedDirectory.delete();
    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'unsafe-delete',
      ),
      isNull,
    );
    await store.delete(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'unsafe-delete',
    );
  });

  test('设备状态删除发布第二代tombstone后清理中断不得复活旧代', () async {
    final state = Uint8List(188)..fillRange(0, 188, 0x24);
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'delete-interrupted',
      blob: state,
    );
    final interruptedStore = DeviceStateBlobStore(
      installationRoot: installationRoot,
      durability: _InterruptAfterDeviceTombstonePublishDurability(
        RestorePlatformDurability(),
      ),
    );

    await expectLater(
      interruptedStore.delete(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'delete-interrupted',
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'delete-interrupted',
      ),
      isNull,
    );
    final locator = await _deviceStateLocatorDirectory(
      installationRoot,
      expectedCount: 1,
    );
    final tombstone = await File(
      p.join(locator.path, 'tombstone.bin'),
    ).readAsBytes();
    expect(ByteData.sublistView(tombstone).getUint64(8, Endian.big), 2);
  });

  test('设备状态删除在tombstone提交点两侧中断时保持原子可见性', () async {
    final beforeRoot = Directory(
      p.join(installationRoot.path, 'before-tombstone-publish'),
    );
    final afterRenameRoot = Directory(
      p.join(installationRoot.path, 'after-tombstone-rename'),
    );
    await beforeRoot.create();
    await afterRenameRoot.create();
    final state = Uint8List(188)..fillRange(0, 188, 0x25);
    final beforeStore = DeviceStateBlobStore(installationRoot: beforeRoot);
    await beforeStore.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'before-tombstone-publish',
      blob: state,
    );

    await expectLater(
      DeviceStateBlobStore(
        installationRoot: beforeRoot,
        durability: _InterruptBeforeDeviceTombstonePublishDurability(
          RestorePlatformDurability(),
        ),
      ).delete(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'before-tombstone-publish',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await beforeStore.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'before-tombstone-publish',
      ),
      orderedEquals(state),
    );

    final afterRenameStore = DeviceStateBlobStore(
      installationRoot: afterRenameRoot,
    );
    await afterRenameStore.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'after-tombstone-rename',
      blob: state,
    );
    await expectLater(
      DeviceStateBlobStore(
        installationRoot: afterRenameRoot,
        durability: _InterruptAfterDeviceTombstoneRenameDurability(
          RestorePlatformDurability(),
        ),
      ).delete(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'after-tombstone-rename',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await afterRenameStore.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'after-tombstone-rename',
      ),
      isNull,
    );
  });

  test('设备状态删除任一清理屏障失败后均不得复活旧代', () async {
    for (final failOnCleanupSync in const <int>[1, 2]) {
      final root = Directory(
        p.join(installationRoot.path, 'cleanup-$failOnCleanupSync'),
      );
      await root.create();
      final store = DeviceStateBlobStore(installationRoot: root);
      await store.write(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'cleanup-$failOnCleanupSync',
        blob: Uint8List(188)..fillRange(0, 188, 0x25 + failOnCleanupSync),
      );

      await expectLater(
        DeviceStateBlobStore(
          installationRoot: root,
          durability: _FailDeviceDeleteCleanupBarrierDurability(
            RestorePlatformDurability(),
            failOnCleanupSync: failOnCleanupSync,
          ),
        ).delete(
          normalizedBaseUrl: 'https://kelivo.bemylover.top',
          normalizedLoginName: 'cleanup-$failOnCleanupSync',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        await store.read(
          normalizedBaseUrl: 'https://kelivo.bemylover.top',
          normalizedLoginName: 'cleanup-$failOnCleanupSync',
        ),
        isNull,
      );
      await store.delete(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'cleanup-$failOnCleanupSync',
      );
    }
  });

  test('设备状态tombstone损坏时读写删均失败关闭且代际上限不回绕', () async {
    final corruptRoot = Directory(
      p.join(installationRoot.path, 'corrupt-tombstone'),
    );
    await corruptRoot.create();
    final corruptStore = DeviceStateBlobStore(installationRoot: corruptRoot);
    await corruptStore.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'corrupt-tombstone',
      blob: Uint8List(188)..fillRange(0, 188, 0x28),
    );
    await corruptStore.delete(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'corrupt-tombstone',
    );
    final corruptLocator = await _deviceStateLocatorDirectory(
      corruptRoot,
      expectedCount: 1,
    );
    final corruptTombstone = File(p.join(corruptLocator.path, 'tombstone.bin'));
    final corruptFrame = await corruptTombstone.readAsBytes();
    corruptFrame[corruptFrame.length - 1] ^= 0xff;
    await corruptTombstone.writeAsBytes(corruptFrame, flush: true);

    await expectLater(
      corruptStore.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'corrupt-tombstone',
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      corruptStore.write(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'corrupt-tombstone',
        blob: Uint8List(188)..fillRange(0, 188, 0x29),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      corruptStore.delete(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'corrupt-tombstone',
      ),
      throwsA(isA<FormatException>()),
    );

    final maximumRoot = Directory(
      p.join(installationRoot.path, 'maximum-tombstone'),
    );
    await maximumRoot.create();
    final maximumStore = DeviceStateBlobStore(installationRoot: maximumRoot);
    await maximumStore.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'maximum-tombstone',
      blob: Uint8List(188)..fillRange(0, 188, 0x2a),
    );
    await maximumStore.delete(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'maximum-tombstone',
    );
    final maximumLocator = await _deviceStateLocatorDirectory(
      maximumRoot,
      expectedCount: 1,
    );
    final maximumTombstone = File(p.join(maximumLocator.path, 'tombstone.bin'));
    final maximumFrame = await maximumTombstone.readAsBytes();
    ByteData.sublistView(
      maximumFrame,
    ).setUint64(8, 0x7fffffffffffffff, Endian.big);
    maximumFrame.setRange(
      16,
      maximumFrame.length,
      sha256.convert(maximumFrame.sublist(0, 16)).bytes,
    );
    await maximumTombstone.writeAsBytes(maximumFrame, flush: true);

    await expectLater(
      maximumStore.write(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'maximum-tombstone',
        blob: Uint8List(188)..fillRange(0, 188, 0x2b),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await maximumStore.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'maximum-tombstone',
      ),
      isNull,
    );
    expect(await maximumTombstone.readAsBytes(), orderedEquals(maximumFrame));
  });

  test('设备状态重建清除tombstone的目录屏障失败时只暴露新代', () async {
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    final oldState = Uint8List(188)..fillRange(0, 188, 0x2c);
    final newState = Uint8List(188)..fillRange(0, 188, 0x2d);
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'tombstone-clear-failure',
      blob: oldState,
    );
    await store.delete(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'tombstone-clear-failure',
    );

    await expectLater(
      DeviceStateBlobStore(
        installationRoot: installationRoot,
        durability: _FailDeviceTombstoneClearBarrierDurability(
          RestorePlatformDurability(),
        ),
      ).write(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'tombstone-clear-failure',
        blob: newState,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'tombstone-clear-failure',
      ),
      orderedEquals(newState),
    );
  });

  test('设备状态只接受188字节且不同规范身份拥有独立代次', () async {
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    expect(
      () => store.write(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'alice',
        blob: Uint8List(187),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => store.write(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'alice',
        blob: Uint8List(189),
      ),
      throwsA(isA<FormatException>()),
    );

    final first = Uint8List(188)..fillRange(0, 188, 0x31);
    final second = Uint8List(188)..fillRange(0, 188, 0x32);
    final third = Uint8List(188)..fillRange(0, 188, 0x33);
    final otherIdentity = Uint8List(188)..fillRange(0, 188, 0x44);
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'alice',
      blob: first,
    );
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'alice',
      blob: second,
    );
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'alice',
      blob: third,
    );
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'Alice',
      blob: otherIdentity,
    );

    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'alice',
      ),
      orderedEquals(third),
    );
    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'Alice',
      ),
      orderedEquals(otherIdentity),
    );
  });

  test('设备状态当前manifest或slot损坏时拒绝回退旧代', () async {
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    final first = Uint8List(188)..fillRange(0, 188, 0x51);
    final second = Uint8List(188)..fillRange(0, 188, 0x52);
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'manifest-corrupt',
      blob: first,
    );
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'manifest-corrupt',
      blob: second,
    );
    var locator = await _deviceStateLocatorDirectory(
      installationRoot,
      expectedCount: 1,
    );
    await File(
      p.join(locator.path, 'manifest-b.bin'),
    ).writeAsBytes(<int>[0x01], flush: true);

    await expectLater(
      store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'manifest-corrupt',
      ),
      throwsA(isA<FormatException>()),
    );

    await store.delete(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'manifest-corrupt',
    );
    final state = Uint8List(188)..fillRange(0, 188, 0x61);
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'manifest-corrupt',
      blob: state,
    );
    locator = await _deviceStateLocatorDirectory(
      installationRoot,
      expectedCount: 1,
    );
    final stateFile = File(p.join(locator.path, 'state-a.bin'));
    final stateFrame = await stateFile.readAsBytes();
    stateFrame[stateFrame.length - 1] ^= 0xff;
    await stateFile.writeAsBytes(stateFrame, flush: true);

    await expectLater(
      store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'manifest-corrupt',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('设备状态slot持久化但manifest发布失败时仍读取旧代', () async {
    final first = Uint8List(188)..fillRange(0, 188, 0x71);
    final second = Uint8List(188)..fillRange(0, 188, 0x72);
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'crash-recovery',
      blob: first,
    );
    final interruptedStore = DeviceStateBlobStore(
      installationRoot: installationRoot,
      durability: _InterruptBeforeDeviceManifestPublishDurability(
        RestorePlatformDurability(),
        manifestSlot: 'b',
      ),
    );

    await expectLater(
      interruptedStore.write(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'crash-recovery',
        blob: second,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'crash-recovery',
      ),
      orderedEquals(first),
    );

    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'crash-recovery',
      blob: second,
    );
    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'crash-recovery',
      ),
      orderedEquals(second),
    );
  });

  test('设备状态写入不使用可预测固定临时路径', () async {
    final first = Uint8List(188)..fillRange(0, 188, 0x73);
    final second = Uint8List(188)..fillRange(0, 188, 0x74);
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'unpredictable-temporary',
      blob: first,
    );
    final locator = await _deviceStateLocatorDirectory(
      installationRoot,
      expectedCount: 1,
    );
    await Directory(p.join(locator.path, '.manifest-b.next')).create();

    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'unpredictable-temporary',
      blob: second,
    );

    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'unpredictable-temporary',
      ),
      orderedEquals(second),
    );

    await Directory(
      p.join(locator.path, '.state-a-00000000000000000000000000000000.next'),
    ).create();
    await expectLater(
      store.write(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'unpredictable-temporary',
        blob: Uint8List(188)..fillRange(0, 188, 0x75),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'unpredictable-temporary',
      ),
      orderedEquals(second),
    );
  });

  test('设备状态locator链接与锁路径错误类型均被拒绝', () async {
    final lockRoot = Directory(p.join(installationRoot.path, 'unsafe-lock'));
    await lockRoot.create();
    final lockStore = DeviceStateBlobStore(installationRoot: lockRoot);
    await lockStore.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'unsafe-lock',
      blob: Uint8List(188)..fillRange(0, 188, 0x75),
    );
    final lockLocator = await _deviceStateLocatorDirectory(
      lockRoot,
      expectedCount: 1,
    );
    await File(p.join(lockLocator.path, '.lock')).delete();
    await Directory(p.join(lockLocator.path, '.lock')).create();

    await expectLater(
      lockStore.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'unsafe-lock',
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      lockStore.write(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'unsafe-lock',
        blob: Uint8List(188)..fillRange(0, 188, 0x76),
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      lockStore.delete(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'unsafe-lock',
      ),
      throwsA(isA<StateError>()),
    );

    final locatorRoot = Directory(
      p.join(installationRoot.path, 'unsafe-locator'),
    );
    await locatorRoot.create();
    final locatorStore = DeviceStateBlobStore(installationRoot: locatorRoot);
    await locatorStore.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'unsafe-locator',
      blob: Uint8List(188)..fillRange(0, 188, 0x77),
    );
    final locator = await _deviceStateLocatorDirectory(
      locatorRoot,
      expectedCount: 1,
    );
    final relocated = Directory(
      p.join(locatorRoot.path, 'relocated-device-state'),
    );
    await locator.rename(relocated.path);
    await _createDirectoryLink(locator.path, relocated.path);

    await expectLater(
      locatorStore.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'unsafe-locator',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('设备状态真实isolate并发写同一locator时由操作系统锁顺序提交', () async {
    final initial = Uint8List(188)..fillRange(0, 188, 0x81);
    final expectedSecondGeneration = Uint8List(188)..fillRange(0, 188, 0x82);
    final expectedFinal = Uint8List(188)..fillRange(0, 188, 0x83);
    final store = DeviceStateBlobStore(installationRoot: installationRoot);
    await store.write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'isolate-lock',
      blob: initial,
    );
    final controls = Directory(p.join(installationRoot.path, 'lock-controls'));
    await controls.create();
    final paused = File(p.join(controls.path, 'first-paused'));
    final release = File(p.join(controls.path, 'release-first'));
    final firstCompleted = File(p.join(controls.path, 'first-completed'));
    final firstError = File(p.join(controls.path, 'first-error'));
    final secondStarted = File(p.join(controls.path, 'second-started'));
    final secondCompleted = File(p.join(controls.path, 'second-completed'));
    final secondError = File(p.join(controls.path, 'second-error'));

    final firstWrite = Isolate.run(
      () => _writeDeviceStateFromIsolate(
        installationRootPath: installationRoot.path,
        value: 0x82,
        startedPath: p.join(controls.path, 'first-started'),
        completedPath: firstCompleted.path,
        errorPath: firstError.path,
        pausePath: paused.path,
        releasePath: release.path,
      ),
    );
    await _waitForFile(paused);
    final secondWrite = Isolate.run(
      () => _writeDeviceStateFromIsolate(
        installationRootPath: installationRoot.path,
        value: 0x83,
        startedPath: secondStarted.path,
        completedPath: secondCompleted.path,
        errorPath: secondError.path,
      ),
    );
    await _waitForFile(secondStarted);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final secondCompletedBeforeRelease = await secondCompleted.exists();
    await release.writeAsString('release', flush: true);
    await Future.wait(<Future<void>>[
      firstWrite,
      secondWrite,
    ]).timeout(const Duration(seconds: 20));

    expect(secondCompletedBeforeRelease, isFalse);
    expect(await firstError.exists(), isFalse);
    expect(await secondError.exists(), isFalse);
    expect(await firstCompleted.exists(), isTrue);
    expect(
      await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'isolate-lock',
      ),
      orderedEquals(expectedFinal),
    );
    final locator = await _deviceStateLocatorDirectory(
      installationRoot,
      expectedCount: 1,
    );
    final manifestB = await File(
      p.join(locator.path, 'manifest-b.bin'),
    ).readAsBytes();
    expect(ByteData.sublistView(manifestB).getUint64(8, Endian.big), 2);
    final stateB = await File(
      p.join(locator.path, 'state-b.bin'),
    ).readAsBytes();
    expect(stateB.sublist(20), orderedEquals(expectedSecondGeneration));
  });

  test('设备状态读与删在真实isolate中等待同一操作系统锁', () async {
    for (final operation in const <String>['read', 'delete']) {
      final root = Directory(
        p.join(installationRoot.path, 'isolate-$operation'),
      );
      await root.create();
      final store = DeviceStateBlobStore(installationRoot: root);
      await store.write(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'isolate-lock',
        blob: Uint8List(188)..fillRange(0, 188, 0x81),
      );
      final controls = Directory(p.join(root.path, 'controls'));
      await controls.create();
      final paused = File(p.join(controls.path, 'writer-paused'));
      final release = File(p.join(controls.path, 'writer-release'));
      final writerError = File(p.join(controls.path, 'writer-error'));
      final operationStarted = File(
        p.join(controls.path, '$operation-started'),
      );
      final operationCompleted = File(
        p.join(controls.path, '$operation-completed'),
      );
      final operationError = File(p.join(controls.path, '$operation-error'));

      final writer = Isolate.run(
        () => _writeDeviceStateFromIsolate(
          installationRootPath: root.path,
          value: 0x82,
          startedPath: p.join(controls.path, 'writer-started'),
          completedPath: p.join(controls.path, 'writer-completed'),
          errorPath: writerError.path,
          pausePath: paused.path,
          releasePath: release.path,
        ),
      );
      await _waitForFile(paused);
      final access = Isolate.run(
        () => _accessDeviceStateFromIsolate(
          installationRootPath: root.path,
          operation: operation,
          startedPath: operationStarted.path,
          completedPath: operationCompleted.path,
          errorPath: operationError.path,
        ),
      );
      await _waitForFile(operationStarted);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final completedBeforeRelease = await operationCompleted.exists();
      await release.writeAsString('release', flush: true);
      await Future.wait(<Future<void>>[
        writer,
        access,
      ]).timeout(const Duration(seconds: 20));

      expect(completedBeforeRelease, isFalse, reason: operation);
      expect(await writerError.exists(), isFalse, reason: operation);
      expect(await operationError.exists(), isFalse, reason: operation);
      if (operation == 'read') {
        expect(await operationCompleted.readAsString(), '130');
      } else {
        expect(
          await store.read(
            normalizedBaseUrl: 'https://kelivo.bemylover.top',
            normalizedLoginName: 'isolate-lock',
          ),
          isNull,
        );
      }
    }
  });

  test('账号工作区磁盘不得持久化 bearer token 明文', () async {
    final session = _session(
      userId: 'account-a',
      token: 'disk-sentinel-bearer-token',
    );
    final token = session.token.value;
    final runtime = await bootstrap();
    await runtime.bindAccount(session);

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
    expect(sessionMetadata['version'], 2);
    expect(sessionMetadata['tokenExpiresAt'], '2030-07-18T00:00:00.000Z');
    expect(sessionMetadata['keyEpoch'], 1);
    expect(payload['tokenReference'], <String, Object?>{
      'version': 1,
      'generation': 1,
      'slot': 'a',
    });
  });

  test('E2EE 已认证会话重启后完整 roundtrip', () async {
    final authenticatedSession = CloudSyncAuthenticatedSession(
      token: _fullSessionToken('authenticated-roundtrip-token'),
      tokenExpiresAt: DateTime.parse('2031-07-26T16:20:00+08:00'),
      keyEpoch: 0xffffffff,
      user: CloudSyncAuthenticatedUser(
        id: '11111111-1111-4111-8111-111111111111',
        loginName: 'roundtrip-user',
        displayName: 'Roundtrip User',
        role: CloudSyncUserRole.admin,
        attachmentQuotaBytes: 4096,
      ),
      device: CloudSyncAuthenticatedDevice(
        id: '22222222-2222-4222-8222-222222222222',
        name: 'Roundtrip Device',
        platform: CloudSyncPlatform.linux,
        clientVersion: '2.0.0',
        status: CloudSyncAuthenticatedDeviceStatus.active,
        createdAt: DateTime.parse('2026-07-25T09:30:00+08:00'),
      ),
    );
    final expected = CloudSyncAccountSession.fromAuthenticatedSession(
      baseUrl: defaultCloudSyncBaseUrl,
      session: authenticatedSession,
    );
    var runtime = await bootstrap();
    await runtime.bindAccount(expected);
    await close(runtime);

    runtime = await bootstrap();
    final restored = runtime.current.session!;
    expect(restored.baseUrl, expected.baseUrl);
    expect(restored.token.value, expected.token.value);
    expect(restored.tokenExpiresAt, DateTime.utc(2031, 7, 26, 8, 20));
    expect(restored.keyEpoch, 0xffffffff);
    expect(restored.userId, expected.userId);
    expect(restored.loginName, expected.loginName);
    expect(restored.displayName, expected.displayName);
    expect(restored.role, expected.role);
    expect(restored.attachmentQuotaBytes, expected.attachmentQuotaBytes);
    expect(restored.deviceId, expected.deviceId);
    expect(restored.deviceName, expected.deviceName);
    expect(restored.platform, expected.platform);
    expect(restored.clientVersion, expected.clientVersion);
    expect(restored.deviceCreatedAt, DateTime.utc(2026, 7, 25, 1, 30));
  });

  test('会话过期判断在到期瞬间生效且不读取系统时间', () {
    final expiresAt = DateTime.utc(2030, 7, 18);
    final session = _session(
      userId: 'expiry-boundary',
      token: 'expiry-boundary-token',
      tokenExpiresAt: expiresAt,
    );

    expect(
      session.isExpiredAt(expiresAt.subtract(const Duration(microseconds: 1))),
      isFalse,
    );
    expect(session.isExpiredAt(expiresAt), isTrue);
    expect(
      session.isExpiredAt(expiresAt.add(const Duration(microseconds: 1))),
      isTrue,
    );
  });

  final invalidSessionFields = <({String name, String field, Object value})>[
    (name: 'userId', field: 'userId', value: 'user-1'),
    (name: 'deviceId', field: 'deviceId', value: 'device-1'),
    (name: 'loginName', field: 'loginName', value: 'Invalid Login'),
    (name: 'displayName', field: 'displayName', value: ' '),
    (
      name: 'deviceName',
      field: 'deviceName',
      value: List<String>.filled(81, 'x').join(),
    ),
    (name: 'clientVersion', field: 'clientVersion', value: '1/0'),
    (name: '负 attachmentQuotaBytes', field: 'attachmentQuotaBytes', value: -1),
    (
      name: '超界 attachmentQuotaBytes',
      field: 'attachmentQuotaBytes',
      value: 9007199254740992,
    ),
  ];
  for (final invalid in invalidSessionFields) {
    test('完整会话 JSON 拒绝非法 ${invalid.name}', () {
      final json = _session(
        userId: 'invalid-${invalid.field}',
        token: 'invalid-${invalid.field}-token',
      ).toJson();
      json[invalid.field] = invalid.value;

      expect(
        () => CloudSyncAccountSession.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  }

  test('完整会话 JSON 拒绝未知字段', () {
    final json = _session(
      userId: 'unknown-json-field',
      token: 'unknown-json-field-token',
    ).toJson()..['unknown'] = true;

    expect(
      () => CloudSyncAccountSession.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('完整会话 JSON 拒绝浮点版本 2.0', () {
    final json = _session(
      userId: 'floating-json-version',
      token: 'floating-json-version-token',
    ).toJson()..['version'] = 2.0;

    expect(
      () => CloudSyncAccountSession.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  for (final invalidTime in <({String field, String value})>[
    (field: 'tokenExpiresAt', value: '2030-07-18T00:00:00.000+00:00'),
    (field: 'deviceCreatedAt', value: '2026-07-18T00:00:00Z'),
  ]) {
    test('完整会话 JSON 拒绝非规范 UTC ${invalidTime.field}', () {
      final json = _session(
        userId: 'invalid-${invalidTime.field}',
        token: 'invalid-${invalidTime.field}-token',
      ).toJson();
      json[invalidTime.field] = invalidTime.value;

      expect(
        () => CloudSyncAccountSession.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  }

  test('会话令牌解密后格式非法时启动失败', () async {
    final runtime = await bootstrap();
    await runtime.bindAccount(
      _session(userId: 'account-a', token: 'invalid-token-source'),
    );
    await close(runtime);
    sessionTokenStore.replaceAllTokens('invalid-token');

    await expectLater(bootstrap(), throwsA(isA<FormatException>()));
  });

  test('会话 metadata 缺失 keyEpoch 时启动失败', () async {
    await expectStoredSessionMetadataRejected(
      (metadata) => metadata.remove('keyEpoch'),
    );
  });

  for (final invalidEpoch in <int>[0, 0x100000000]) {
    test('会话 metadata 包含非法 keyEpoch $invalidEpoch 时启动失败', () async {
      await expectStoredSessionMetadataRejected(
        (metadata) => metadata['keyEpoch'] = invalidEpoch,
      );
    });
  }

  test('会话 metadata 缺失 tokenExpiresAt 时启动失败', () async {
    await expectStoredSessionMetadataRejected(
      (metadata) => metadata.remove('tokenExpiresAt'),
    );
  });

  test('会话 metadata 包含非法 tokenExpiresAt 时启动失败', () async {
    await expectStoredSessionMetadataRejected(
      (metadata) => metadata['tokenExpiresAt'] = 'not-a-date-time',
    );
  });

  test('旧版会话 metadata 启动时拒绝迁移', () async {
    await expectStoredSessionMetadataRejected(
      (metadata) => metadata['version'] = 1,
    );
  });

  test('会话 metadata 拒绝浮点版本 2.0', () async {
    await expectStoredSessionMetadataRejected(
      (metadata) => metadata['version'] = 2.0,
    );
  });

  test('会话 metadata 拒绝未知字段', () async {
    await expectStoredSessionMetadataRejected(
      (metadata) => metadata['unknown'] = true,
    );
  });

  test('会话 metadata 拒绝非规范 UTC 时间', () async {
    await expectStoredSessionMetadataRejected(
      (metadata) =>
          metadata['tokenExpiresAt'] = '2030-07-18T00:00:00.000+00:00',
    );
  });

  test('旧版明文会话启动时硬切并清除凭证', () async {
    var runtime = await bootstrap();
    final session = _session(
      userId: 'account-a',
      token: 'legacy-plaintext-token-sentinel',
    );
    final legacyToken = session.token.value;
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
    expect(runtime.current.session?.userId, accountA.userId);
    expect(runtime.current.dataDirectory.path, targetA.dataDirectory.path);

    final bindB = await runtime.bindAccount(accountB);
    expect(bindB, isA<AccountWorkspaceRestartRequired>());
    final targetB = (bindB as AccountWorkspaceRestartRequired).target;
    expect(runtime.current.session?.userId, accountA.userId);
    expect(targetB.dataDirectory.path, isNot(targetA.dataDirectory.path));
    expect(targetB.preferencesPrefix, isNot(targetA.preferencesPrefix));

    await close(runtime);
    runtime = await bootstrap();
    expect(runtime.current.session?.userId, accountB.userId);
    expect(runtime.current.dataDirectory.path, targetB.dataDirectory.path);
  });

  test('硬切清理本地与所有账号工作区的明文同步状态并保留密文凭证', () async {
    var runtime = await bootstrap();
    final bindA = await runtime.bindAccount(
      _session(userId: 'account-a', token: 'token-a'),
    );
    final targetA = (bindA as AccountWorkspaceRestartRequired).target;
    await close(runtime);

    runtime = await bootstrap();
    final bindB = await runtime.bindAccount(
      _session(userId: 'account-b', token: 'token-b'),
    );
    final targetB = (bindB as AccountWorkspaceRestartRequired).target;
    await close(runtime);

    final artifacts = <File>[
      File(
        p.join(
          installationRoot.path,
          '${CloudSyncStateRetirement.legacyBoxName}.hive',
        ),
      ),
      File(
        p.join(
          targetA.dataDirectory.path,
          '${CloudSyncStateRetirement.legacyBoxName}.hivec',
        ),
      ),
      File(
        p.join(
          targetB.dataDirectory.path,
          '${CloudSyncStateRetirement.legacyBoxName}.lock',
        ),
      ),
    ];
    for (final artifact in artifacts) {
      await artifact.writeAsString('legacy-plaintext');
    }
    final legacyHiveArtifacts = <File>[
      File(p.join(installationRoot.path, 'conversations.hive')),
      File(p.join(targetA.dataDirectory.path, 'messages.hivec')),
      File(p.join(targetB.dataDirectory.path, 'tool_events_v1.lock')),
    ];
    for (final artifact in legacyHiveArtifacts) {
      await artifact.writeAsString('legacy-hive-plaintext');
    }
    final databaseArtifacts = <File>[
      for (final dataDirectory in <Directory>[
        installationRoot,
        targetA.dataDirectory,
        targetB.dataDirectory,
      ])
        File(p.join(dataDirectory.path, AppDatabase.databaseFileName)),
    ];
    for (final databaseArtifact in databaseArtifacts) {
      await databaseArtifact.writeAsBytes([
        ...ascii.encode('SQLite format 3\u0000'),
        1,
      ]);
    }
    final sessionRecords = await installationRoot
        .list(recursive: true, followLinks: false)
        .where(
          (entity) =>
              entity is File &&
              p.basename(entity.path).startsWith('session-v2-'),
        )
        .cast<File>()
        .toList();
    expect(sessionRecords, hasLength(2));
    expect(sessionTokenStore.tokenCount, 2);

    runtime = await bootstrap();
    await runtime.discardPlaintextLocalState();

    for (final artifact in artifacts) {
      expect(await artifact.exists(), isFalse, reason: artifact.path);
    }
    for (final artifact in legacyHiveArtifacts) {
      expect(await artifact.exists(), isFalse, reason: artifact.path);
    }
    for (final databaseArtifact in databaseArtifacts) {
      expect(
        await databaseArtifact.exists(),
        isFalse,
        reason: databaseArtifact.path,
      );
    }
    for (final sessionRecord in sessionRecords) {
      expect(await sessionRecord.exists(), isTrue, reason: sessionRecord.path);
    }
    expect(sessionTokenStore.tokenCount, 2);
  });

  test('任一非当前工作区存在未知同步拓扑时整批清理失败且不先删本地状态', () async {
    var runtime = await bootstrap();
    final bind = await runtime.bindAccount(
      _session(userId: 'account-a', token: 'token-a'),
    );
    final account = (bind as AccountWorkspaceRestartRequired).target;
    await close(runtime);

    final localArtifact = File(
      p.join(
        installationRoot.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    final unknownArtifact = File(
      p.join(
        account.dataDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.unknown',
      ),
    );
    await localArtifact.writeAsString('local-plaintext');
    await unknownArtifact.writeAsString('ambiguous');

    runtime = await bootstrap();
    await expectLater(
      runtime.discardPlaintextLocalState(),
      throwsA(isA<StateError>()),
    );

    expect(await localArtifact.exists(), isTrue);
    expect(await unknownArtifact.exists(), isTrue);
  });

  test('非当前工作区存在未知 Hive 拓扑时整批清理失败且不先删本地状态', () async {
    var runtime = await bootstrap();
    final bind = await runtime.bindAccount(
      _session(userId: 'account-a', token: 'token-a'),
    );
    final account = (bind as AccountWorkspaceRestartRequired).target;
    await close(runtime);

    final localArtifact = File(
      p.join(installationRoot.path, 'conversations.hive'),
    );
    final unknownArtifact = File(
      p.join(account.dataDirectory.path, 'messages.hive.partial'),
    );
    await localArtifact.writeAsString('local-legacy');
    await unknownArtifact.writeAsString('ambiguous');

    runtime = await bootstrap();
    await expectLater(
      runtime.discardPlaintextLocalState(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'legacy_retirement_unknown_topology',
        ),
      ),
    );

    expect(await localArtifact.exists(), isTrue);
    expect(await unknownArtifact.exists(), isTrue);
  });

  test('账号目录出现非工作区条目时整批明文清理失败且不先删本地状态', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    final localArtifact = File(
      p.join(
        installationRoot.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    await localArtifact.writeAsString('local-plaintext');
    final unknownEntry = File(
      p.join(
        installationRoot.path,
        '.kelivo-workspaces',
        'accounts',
        'not-a-workspace',
      ),
    );
    await unknownEntry.writeAsString('ambiguous');

    runtime = await bootstrap();
    await expectLater(
      runtime.discardPlaintextLocalState(),
      throwsA(isA<StateError>()),
    );

    expect(await localArtifact.exists(), isTrue);
    expect(await unknownEntry.exists(), isTrue);
  });

  test('非当前账号数据目录链接使整批明文清理失败且不先删本地状态', () async {
    var runtime = await bootstrap();
    final bindA = await runtime.bindAccount(
      _session(userId: 'account-a', token: 'token-a'),
    );
    final accountA = (bindA as AccountWorkspaceRestartRequired).target;
    await close(runtime);

    runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-b', token: 'token-b'));
    await close(runtime);

    final redirectedData = Directory(
      p.join(installationRoot.path, 'redirected-account-a-data'),
    );
    await accountA.dataDirectory.rename(redirectedData.path);
    await _createDirectoryLink(
      accountA.dataDirectory.path,
      redirectedData.path,
    );
    final localArtifact = File(
      p.join(
        installationRoot.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    await localArtifact.writeAsString('local-plaintext');

    runtime = await bootstrap();
    await expectLater(
      runtime.discardPlaintextLocalState(),
      throwsA(isA<StateError>()),
    );

    expect(await localArtifact.exists(), isTrue);
    expect(
      await FileSystemEntity.type(
        accountA.dataDirectory.path,
        followLinks: false,
      ),
      isNot(FileSystemEntityType.directory),
    );
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
    expect(runtime.current.session?.token.value, refreshed.token.value);

    await close(runtime);
    runtime = await bootstrap();
    expect(runtime.current.dataDirectory.path, originalPath);
    expect(runtime.current.session?.token.value, refreshed.token.value);
  });

  test('会话 metadata 提交后清理失败仍切换会话并由下次启动清理', () async {
    var runtime = await bootstrap();
    final original = _session(userId: 'account-a', token: 'old-token');
    await runtime.bindAccount(original);
    await close(runtime);

    runtime = await bootstrap();
    final refreshed = _session(userId: 'account-a', token: 'new-token');
    sessionTokenStore.failNextDelete = true;
    final result = await runtime.bindAccount(refreshed);

    expect(result, isA<AccountWorkspaceRetained>());
    expect(runtime.current.session?.token.value, refreshed.token.value);
    expect(sessionTokenStore.tokenCount, 2);
    await close(runtime);

    runtime = await bootstrap();
    expect(runtime.current.session?.token.value, refreshed.token.value);
    expect(sessionTokenStore.tokenCount, 1);
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

  test('账号会话在到期前一微秒仍恢复原工作区', () async {
    final expiresAt = DateTime.utc(2030, 7, 18);
    var runtime = await bootstrap();
    final session = _session(
      userId: 'not-expired-account',
      token: 'not-expired-token',
      tokenExpiresAt: expiresAt,
    );
    await runtime.bindAccount(session);
    await close(runtime);

    runtime = await bootstrap(
      utcNow: () => expiresAt.subtract(const Duration(microseconds: 1)),
    );

    expect(runtime.current.session?.token.value, session.token.value);
    expect(sessionTokenStore.tokenCount, 1);
  });

  test('账号会话在到期瞬间失效并切回匿名工作区', () async {
    final expiresAt = DateTime.utc(2030, 7, 18);
    var runtime = await bootstrap();
    await runtime.bindAccount(
      _session(
        userId: 'expired-account',
        token: 'expired-token',
        tokenExpiresAt: expiresAt,
      ),
    );
    await close(runtime);

    runtime = await bootstrap(utcNow: () => expiresAt);

    expect(runtime.current.isLocal, isTrue);
    expect(runtime.current.session, isNull);
    expect(sessionTokenStore.tokenCount, 0);
  });

  test('账号会话到期提交后令牌删除失败仍切回匿名工作区并重试清理', () async {
    final expiresAt = DateTime.utc(2030, 7, 18);
    var runtime = await bootstrap();
    await runtime.bindAccount(
      _session(
        userId: 'expired-cleanup-account',
        token: 'expired-cleanup-token',
        tokenExpiresAt: expiresAt,
      ),
    );
    await close(runtime);

    sessionTokenStore.failNextDeleteAll = true;
    runtime = await bootstrap(utcNow: () => expiresAt);

    expect(runtime.current.isLocal, isTrue);
    expect(runtime.current.session, isNull);
    expect(sessionTokenStore.tokenCount, 1);
    await close(runtime);

    runtime = await bootstrap(utcNow: () => expiresAt);
    expect(runtime.current.isLocal, isTrue);
    expect(sessionTokenStore.tokenCount, 0);
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

  test('退出提交后令牌删除失败仍完成退出并由下次启动清理', () async {
    var runtime = await bootstrap();
    await runtime.bindAccount(_session(userId: 'account-a', token: 'token-a'));
    await close(runtime);

    runtime = await bootstrap();
    sessionTokenStore.failNextDelete = true;
    final result = await runtime.signOut();

    expect(result.target.isLocal, isTrue);
    expect(runtime.current.session, isNull);
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

Future<void> _writeDeviceStateFromIsolate({
  required String installationRootPath,
  required int value,
  required String startedPath,
  required String completedPath,
  required String errorPath,
  String? pausePath,
  String? releasePath,
}) async {
  await File(startedPath).writeAsString('started', flush: true);
  final RestoreDurability durability;
  if (pausePath != null && releasePath != null) {
    durability = _PauseBeforeDeviceManifestPublishDurability(
      RestorePlatformDurability(),
      pausedFile: File(pausePath),
      releaseFile: File(releasePath),
    );
  } else {
    durability = RestorePlatformDurability();
  }
  try {
    await DeviceStateBlobStore(
      installationRoot: Directory(installationRootPath),
      durability: durability,
    ).write(
      normalizedBaseUrl: 'https://kelivo.bemylover.top',
      normalizedLoginName: 'isolate-lock',
      blob: Uint8List(188)..fillRange(0, 188, value),
    );
    await File(completedPath).writeAsString('completed', flush: true);
  } catch (error, stackTrace) {
    await File(errorPath).writeAsString('$error\n$stackTrace', flush: true);
  }
}

Future<void> _accessDeviceStateFromIsolate({
  required String installationRootPath,
  required String operation,
  required String startedPath,
  required String completedPath,
  required String errorPath,
}) async {
  await File(startedPath).writeAsString('started', flush: true);
  final store = DeviceStateBlobStore(
    installationRoot: Directory(installationRootPath),
  );
  try {
    if (operation == 'read') {
      final state = await store.read(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'isolate-lock',
      );
      if (state == null) throw StateError('device_state_test_missing_state');
      await File(completedPath).writeAsString('${state.first}', flush: true);
    } else if (operation == 'delete') {
      await store.delete(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'isolate-lock',
      );
      await File(completedPath).writeAsString('completed', flush: true);
    } else {
      throw StateError('device_state_test_unknown_operation');
    }
  } catch (error, stackTrace) {
    await File(errorPath).writeAsString('$error\n$stackTrace', flush: true);
  }
}

Future<void> _waitForFile(File file) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!await file.exists()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
        'device_state_test_signal_timeout',
        const Duration(seconds: 10),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<Directory> _deviceStateLocatorDirectory(
  Directory installationRoot, {
  required int expectedCount,
}) async {
  final root = Directory(
    p.join(installationRoot.path, '.kelivo-device-state-v1'),
  );
  final directories = await root
      .list(followLinks: false)
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();
  expect(directories, hasLength(expectedCount));
  return directories.single;
}

final class _PauseBeforeDeviceManifestPublishDurability
    implements RestoreDurability {
  _PauseBeforeDeviceManifestPublishDurability(
    this.delegate, {
    required this.pausedFile,
    required this.releaseFile,
  });

  final RestoreDurability delegate;
  final File pausedFile;
  final File releaseFile;
  bool _paused = false;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) {
    return delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) {
    return delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) {
    return delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    final sourceName = p.basename(source.path);
    if (!_paused &&
        sourceName.startsWith('.manifest-') &&
        sourceName.endsWith('.next')) {
      _paused = true;
      await pausedFile.writeAsString('paused', flush: true);
      await _waitForFile(releaseFile);
    }
    await delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}

final class _InterruptBeforeDeviceManifestPublishDurability
    implements RestoreDurability {
  _InterruptBeforeDeviceManifestPublishDurability(
    this.delegate, {
    required this.manifestSlot,
  });

  final RestoreDurability delegate;
  final String manifestSlot;
  bool _interrupted = false;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) {
    return delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) {
    return delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) {
    return delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) {
    final sourceName = p.basename(source.path);
    if (!_interrupted &&
        sourceName.startsWith('.manifest-$manifestSlot-') &&
        sourceName.endsWith('.next')) {
      _interrupted = true;
      throw StateError('device_state_manifest_publish_interrupted');
    }
    return delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}

final class _InterruptBeforeDeviceTombstonePublishDurability
    implements RestoreDurability {
  _InterruptBeforeDeviceTombstonePublishDurability(this.delegate);

  final RestoreDurability delegate;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) {
    return delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) {
    return delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) {
    return delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) {
    if (p.basename(targetPath) == 'tombstone.bin') {
      throw StateError('device_state_tombstone_publish_interrupted');
    }
    return delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}

final class _InterruptAfterDeviceTombstoneRenameDurability
    implements RestoreDurability {
  _InterruptAfterDeviceTombstoneRenameDurability(this.delegate);

  final RestoreDurability delegate;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) {
    return delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) {
    return delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) {
    return delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    if (p.basename(targetPath) == 'tombstone.bin') {
      await File(source.path).rename(targetPath);
      throw StateError('device_state_tombstone_directory_barrier_interrupted');
    }
    await delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}

final class _InterruptAfterPendingRegistrationRenameDurability
    implements RestoreDurability {
  _InterruptAfterPendingRegistrationRenameDurability(this.delegate);

  final RestoreDurability delegate;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) {
    return delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) {
    return delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) {
    return delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    if (p.basename(targetPath) == 'registration-pending.bin') {
      await File(source.path).rename(targetPath);
      throw StateError(
        'device_state_registration_directory_barrier_interrupted',
      );
    }
    await delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}

final class _InterruptAfterPendingPairingRenameDurability
    implements RestoreDurability {
  _InterruptAfterPendingPairingRenameDurability(this.delegate);

  final RestoreDurability delegate;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) {
    return delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) {
    return delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) {
    return delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    if (p.basename(targetPath) == 'pairing-pending.bin') {
      await File(source.path).rename(targetPath);
      throw StateError('device_state_pairing_directory_barrier_interrupted');
    }
    await delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}

final class _FailDeviceDeleteCleanupBarrierDurability
    implements RestoreDurability {
  _FailDeviceDeleteCleanupBarrierDurability(
    this.delegate, {
    required this.failOnCleanupSync,
  });

  final RestoreDurability delegate;
  final int failOnCleanupSync;
  bool _tombstonePublished = false;
  int _cleanupSyncCount = 0;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) {
    return delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) {
    if (_tombstonePublished) {
      _cleanupSyncCount += 1;
      if (_cleanupSyncCount == failOnCleanupSync) {
        throw StateError('device_state_delete_cleanup_barrier_interrupted');
      }
    }
    return delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) {
    return delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (p.basename(targetPath) == 'tombstone.bin') {
      _tombstonePublished = true;
    }
  }
}

final class _FailDeviceTombstoneClearBarrierDurability
    implements RestoreDurability {
  _FailDeviceTombstoneClearBarrierDurability(this.delegate);

  final RestoreDurability delegate;
  bool _failed = false;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) {
    return delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    final tombstone = File(p.join(directory.path, 'tombstone.bin'));
    final manifest = File(p.join(directory.path, 'manifest-a.bin'));
    if (!_failed && !await tombstone.exists() && await manifest.exists()) {
      _failed = true;
      throw StateError('device_state_tombstone_clear_barrier_interrupted');
    }
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) {
    return delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) {
    return delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}

final class _InterruptAfterDeviceTombstonePublishDurability
    implements RestoreDurability {
  _InterruptAfterDeviceTombstonePublishDurability(this.delegate);

  final RestoreDurability delegate;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) {
    return delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) {
    return delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) {
    return delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (p.basename(targetPath) == 'tombstone.bin') {
      throw StateError('device_state_tombstone_cleanup_interrupted');
    }
  }
}

final class _MemoryAccountSessionTokenStore
    implements AccountSessionTokenStore {
  final Map<String, String> _tokens = <String, String>{};
  bool failNextDelete = false;
  bool failNextDeleteAll = false;

  int get tokenCount => _tokens.length;

  void clear() => _tokens.clear();

  void replaceAllTokens(String token) {
    _tokens.updateAll((_, _) => token);
  }

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
    if (failNextDelete || (failNextDeleteAll && keep == null)) {
      failNextDelete = false;
      failNextDeleteAll = false;
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
  DateTime? tokenExpiresAt,
}) {
  return CloudSyncAccountSession(
    baseUrl: baseUrl,
    token: _fullSessionToken(token),
    tokenExpiresAt: tokenExpiresAt ?? DateTime.utc(2030, 7, 18),
    keyEpoch: 1,
    userId: _testUuid('user:$userId'),
    loginName: userId.toLowerCase(),
    displayName: userId,
    role: CloudSyncUserRole.user,
    attachmentQuotaBytes: 1024,
    deviceId: _testUuid('device:$userId'),
    deviceName: 'Device $userId',
    platform: CloudSyncPlatform.windows,
    clientVersion: '1.0.0',
    deviceCreatedAt: DateTime.utc(2026, 7, 18),
  );
}

CloudSyncFullSessionToken _fullSessionToken(String seed) {
  final payload = base64Url
      .encode(sha256.convert(utf8.encode(seed)).bytes)
      .replaceAll('=', '');
  return CloudSyncFullSessionToken.parse('kelivo_$payload');
}

String _testUuid(String seed) {
  final hex = sha256.convert(utf8.encode(seed)).toString();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '4${hex.substring(13, 16)}-8${hex.substring(17, 20)}-'
      '${hex.substring(20, 32)}';
}
