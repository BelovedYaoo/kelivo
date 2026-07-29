import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_state_retirement.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_cipher.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_state.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';

const _stateTestUserId = '10000000-0000-4000-8000-000000000001';
const _stateTestOperationId1 = '20000000-0000-4000-8000-000000000001';
const _stateTestOperationId2 = '20000000-0000-4000-8000-000000000002';
const _stateTestOperationId3 = '20000000-0000-4000-8000-000000000003';
const _stateTestOperationId4 = '20000000-0000-4000-8000-000000000004';
const _stateTestWriterDeviceId = '30000000-0000-4000-8000-000000000001';
const _stateTestEntityKey = SyncEntityKey(
  entityType: 'conversation',
  entityId: 'conversation-1',
);

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kelivo_cloud_sync_state_retirement_test_',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('硬切删除明文同步状态完整文件族并保留账号工作区密文', () async {
    final plaintextArtifacts = <File>[
      for (final suffix in const <String>['.hive', '.hivec', '.lock'])
        File(
          p.join(
            tempDirectory.path,
            '${CloudSyncStateRetirement.legacyBoxName}$suffix',
          ),
        ),
    ];
    for (final artifact in plaintextArtifacts) {
      await artifact.writeAsString('shadow-and-outbox-plaintext');
    }
    final encryptedAccountArtifacts = <File>[
      File(p.join(tempDirectory.path, 'session-v2')),
      File(p.join(tempDirectory.path, 'token-v1-device.bin')),
    ];
    for (final artifact in encryptedAccountArtifacts) {
      await artifact.writeAsString('encrypted-account-record');
    }

    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: tempDirectory,
    );

    for (final artifact in plaintextArtifacts) {
      expect(await artifact.exists(), isFalse);
    }
    for (final artifact in encryptedAccountArtifacts) {
      expect(await artifact.readAsString(), 'encrypted-account-record');
    }
  });

  test('硬切发现同前缀未知文件时拒绝清理且不触碰任何状态', () async {
    final plaintextArtifact = File(
      p.join(
        tempDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    final unknownArtifact = File(
      p.join(
        tempDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive-journal',
      ),
    );
    await plaintextArtifact.writeAsString('shadow-plaintext');
    await unknownArtifact.writeAsString('unknown-topology');

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: tempDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await plaintextArtifact.readAsString(), 'shadow-plaintext');
    expect(await unknownArtifact.readAsString(), 'unknown-topology');
    expect(
      await File(
        p.join(tempDirectory.path, '.cloud-sync-state-retirement-v1'),
      ).exists(),
      isFalse,
    );
  });

  test('硬切按大小写不敏感前缀识别未知拓扑并拒绝启动', () async {
    final unknownArtifact = File(
      p.join(tempDirectory.path, 'CLOUD_SYNC_STATE_V1.unknown'),
    );
    await unknownArtifact.writeAsString('unknown-topology');

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: tempDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await unknownArtifact.readAsString(), 'unknown-topology');
  });

  test('硬切在没有旧同步状态时保持幂等且不创建清理标记', () async {
    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: tempDirectory,
    );
    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: tempDirectory,
    );

    expect(await tempDirectory.list().toList(), isEmpty);
  });

  test('硬切发现旧同步状态同名目录时拒绝清理', () async {
    final unexpectedDirectory = Directory(
      p.join(
        tempDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    await unexpectedDirectory.create();

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: tempDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await unexpectedDirectory.exists(), isTrue);
  });

  test('硬切发现旧同步状态符号链接时拒绝跟随和清理', () async {
    final encryptedAccountArtifact = File(
      p.join(tempDirectory.path, 'session-v2'),
    );
    await encryptedAccountArtifact.writeAsString('encrypted-account-record');
    final unexpectedLink = Link(
      p.join(
        tempDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    await unexpectedLink.create(encryptedAccountArtifact.path);

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: tempDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await unexpectedLink.exists(), isTrue);
    expect(
      await encryptedAccountArtifact.readAsString(),
      'encrypted-account-record',
    );
  });

  test('硬切在清理标记耐久后中断并于下次启动无条件续删', () async {
    final plaintextArtifact = File(
      p.join(
        tempDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    await plaintextArtifact.writeAsString('shadow-plaintext');
    final marker = File(
      p.join(tempDirectory.path, '.cloud-sync-state-retirement-v1'),
    );
    final interruptingDurability = _InterruptAfterMarkerDurability(
      delegate: RestorePlatformDurability(),
      markerPath: marker.path,
      plaintextArtifactPath: plaintextArtifact.path,
    );

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: tempDirectory,
        durability: interruptingDurability,
      ),
      throwsA(isA<StateError>()),
    );

    expect(interruptingDurability.markerWasDurableBeforeInterruption, isTrue);
    expect(await marker.exists(), isTrue);
    expect(await plaintextArtifact.exists(), isTrue);

    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: tempDirectory,
    );

    expect(await marker.exists(), isFalse);
    expect(await plaintextArtifact.exists(), isFalse);
  });

  test('仅本地写执行器只执行一次写入并返回本地结果', () async {
    const executor = LocalOnlySyncWriteExecutor();
    var writeCount = 0;

    final result = await executor.runLocal(
      key: const SyncEntityKey(entityType: 'chat', entityId: 'chat-1'),
      write: () async {
        writeCount += 1;
        return 'local-result';
      },
    );

    expect(result, 'local-result');
    expect(writeCount, 1);
  });

  test('仅本地批量写不遍历实体键且只执行本地写入', () async {
    const executor = LocalOnlySyncWriteExecutor();
    var writeCount = 0;

    final result = await executor.runLocalBatch(
      keys: _unreadableSyncEntityKeys(),
      write: () async {
        writeCount += 1;
        return 7;
      },
    );

    expect(result, 7);
    expect(writeCount, 1);
  });

  test('仅本地写执行器原样透传写入异常', () async {
    const executor = LocalOnlySyncWriteExecutor();

    await expectLater(
      executor.runLocal<void>(
        key: const SyncEntityKey(entityType: 'chat', entityId: 'chat-error'),
        write: () => throw StateError('local-write-failed'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'local-write-failed',
        ),
      ),
    );
  });

  test('认证记录状态往返值与墓碑并清零借用明文', () async {
    final codec = await _createStateCodec();
    addTearDown(codec.close);
    final valuePayload = Uint8List.fromList(<int>[1, 2, 3]);
    final value = await codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _stateTestOperationId1,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: valuePayload,
    );

    Uint8List? borrowedPayload;
    final openedValue = await codec.open(
      _untrustedStateRecord(value),
      decode: (state, payload) {
        borrowedPayload = payload;
        return (state: state, payload: Uint8List.fromList(payload));
      },
    );
    expect(openedValue.state.recordId, value.record.recordId);
    expect(openedValue.state.entityKey, _stateTestEntityKey);
    expect(openedValue.state.digest, value.digest);
    expect(openedValue.state.kind, E2eeAccountRecordStateKind.value);
    expect(openedValue.state.logicalVersion, 1);
    expect(openedValue.state.parentDigests, isEmpty);
    expect(openedValue.state.operationId, _stateTestOperationId1);
    expect(openedValue.state.claimedWriterDeviceId, _stateTestWriterDeviceId);
    expect(openedValue.state.claimedWriterKeyVersion, 1);
    expect(openedValue.state.keyEpoch, 7);
    expect(openedValue.payload, orderedEquals(valuePayload));
    expect(borrowedPayload, everyElement(0));
    expect(valuePayload, orderedEquals(<int>[1, 2, 3]));

    final tombstone = await codec.sealTombstone(
      entityKey: _stateTestEntityKey,
      logicalVersion: 2,
      parentDigests: <E2eeAccountRecordStateDigest>[value.digest],
      operationId: _stateTestOperationId2,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
    );
    final openedTombstone = await codec.open(
      _untrustedStateRecord(tombstone),
      decode: (state, payload) => (state: state, payloadLength: payload.length),
    );
    expect(tombstone.record.recordId, value.record.recordId);
    expect(openedTombstone.state.kind, E2eeAccountRecordStateKind.tombstone);
    expect(openedTombstone.state.logicalVersion, 2);
    expect(openedTombstone.state.parentDigests, <Object>[value.digest]);
    expect(openedTombstone.payloadLength, 0);
  });

  test('认证记录状态从持久化信封重建发送态并逐字节复用密文', () async {
    final codec = await _createStateCodec();
    addTearDown(codec.close);
    final sealed = await codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _stateTestOperationId1,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final persistedCiphertext = Uint8List.fromList(sealed.record.ciphertext);

    final restored = await codec.restoreForSend(
      _untrustedStateRecord(sealed, ciphertext: persistedCiphertext),
      expectedDigest: sealed.digest,
    );

    expect(codec.currentKeyEpoch, 7);
    expect(
      await codec.deriveRecordId(_stateTestEntityKey),
      sealed.record.recordId,
    );
    expect(restored.sealed.record.recordId, sealed.record.recordId);
    expect(restored.sealed.record.keyEpoch, sealed.record.keyEpoch);
    expect(
      restored.sealed.record.ciphertext,
      orderedEquals(persistedCiphertext),
    );
    expect(restored.sealed.record.ciphertext, isNot(same(persistedCiphertext)));
    expect(restored.sealed.digest, sealed.digest);
    expect(restored.sealed.kind, sealed.kind);
    expect(restored.sealed.logicalVersion, sealed.logicalVersion);
    expect(restored.sealed.parentDigests, sealed.parentDigests);
    expect(restored.sealed.operationId, sealed.operationId);
    expect(restored.sealed.claimedWriterDeviceId, sealed.claimedWriterDeviceId);
    expect(
      restored.sealed.claimedWriterKeyVersion,
      sealed.claimedWriterKeyVersion,
    );
    expect(restored.authenticated.entityKey, _stateTestEntityKey);
    expect(restored.authenticated.digest, sealed.digest);
    expect(persistedCiphertext, orderedEquals(sealed.record.ciphertext));
  });

  test('当前密钥世代可恢复并打开同一 ARK 的历史世代状态', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;

    final random = Random.secure();
    final slot = await core.createSlot(
      Uint8List.fromList(List<int>.generate(16, (_) => random.nextInt(256))),
    );
    addTearDown(() => core.close(slot));
    final identity = await core.generateDeviceIdentity();
    addTearDown(() => core.closeDeviceIdentity(identity));

    KelivoAccountRootKeyHandle? sourceArk = await core.generateAccountRootKey(
      keyEpoch: 6,
    );
    addTearDown(() async {
      final handle = sourceArk;
      if (handle != null) await core.closeAccountRootKey(handle);
    });
    final epoch7Source = await core.generateAccountRootKey(keyEpoch: 7);
    try {
      await core.addAccountRootKeyEpoch(sourceArk, source: epoch7Source);
    } finally {
      await core.closeAccountRootKey(epoch7Source);
    }
    final stateBlob = await core.sealDeviceState(
      slot,
      identity,
      deviceId: _rawStateUuid(_stateTestWriterDeviceId),
      keyVersion: 1,
      ark: sourceArk,
      account: KelivoDeviceStateAccountBinding(
        userId: _rawStateUuid(_stateTestUserId),
        keyEpoch: 7,
      ),
    );
    final reopened = await core.openDeviceState(slot, stateBlob: stateBlob);
    addTearDown(() => core.closeDeviceIdentity(reopened.identity));
    KelivoAccountRootKeyHandle? reopenedArk = reopened.ark;
    addTearDown(() async {
      final handle = reopenedArk;
      if (handle != null) await core.closeAccountRootKey(handle);
    });
    expect(reopenedArk, isNotNull);

    final epoch6Ark = sourceArk;
    final epoch6Codec = E2eeAccountRecordStateCodec.takeOwnership(
      E2eeAccountRecordCipher.takeOwnership(
        secureCore: core,
        accountRootKey: epoch6Ark,
        userId: _stateTestUserId,
        currentKeyEpoch: 6,
      ),
    );
    sourceArk = null;
    addTearDown(epoch6Codec.close);

    final epoch7Ark = reopenedArk!;
    final epoch7Codec = E2eeAccountRecordStateCodec.takeOwnership(
      E2eeAccountRecordCipher.takeOwnership(
        secureCore: core,
        accountRootKey: epoch7Ark,
        userId: _stateTestUserId,
        currentKeyEpoch: 7,
      ),
    );
    reopenedArk = null;
    addTearDown(epoch7Codec.close);

    final payload = Uint8List.fromList(<int>[6, 7, 8]);
    final sealed = await epoch6Codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _stateTestOperationId1,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: payload,
    );
    final persistedCiphertext = Uint8List.fromList(sealed.record.ciphertext);
    final envelope = _untrustedStateRecord(
      sealed,
      ciphertext: persistedCiphertext,
    );

    final restored = await epoch7Codec.restoreForSend(
      envelope,
      expectedDigest: sealed.digest,
    );
    final opened = await epoch7Codec.open(
      envelope,
      decode: (state, borrowedPayload) =>
          (state: state, payload: Uint8List.fromList(borrowedPayload)),
    );

    expect(epoch7Codec.currentKeyEpoch, 7);
    expect(sealed.record.keyEpoch, 6);
    expect(restored.sealed.record.keyEpoch, 6);
    expect(restored.authenticated.keyEpoch, 6);
    expect(
      restored.sealed.record.ciphertext,
      orderedEquals(persistedCiphertext),
    );
    expect(restored.sealed.digest, sealed.digest);
    expect(opened.state.keyEpoch, 6);
    expect(opened.state.digest, sealed.digest);
    expect(opened.payload, orderedEquals(payload));
  });

  test('认证记录状态重建发送态拒绝摘要与信封篡改', () async {
    final codec = await _createStateCodec();
    addTearDown(codec.close);
    final sealed = await codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _stateTestOperationId1,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final wrongDigest = E2eeAccountRecordStateDigest.fromTrustedStorage(
      Uint8List.fromList(
        List<int>.filled(e2eeAccountRecordStateDigestBytes, 0x5a),
      ),
    );
    await expectLater(
      codec.restoreForSend(
        _untrustedStateRecord(sealed),
        expectedDigest: wrongDigest,
      ),
      throwsA(isA<FormatException>()),
    );

    final tamperedCiphertext = Uint8List.fromList(sealed.record.ciphertext);
    tamperedCiphertext[tamperedCiphertext.length - 1] ^= 1;
    await expectLater(
      codec.restoreForSend(
        _untrustedStateRecord(sealed, ciphertext: tamperedCiphertext),
        expectedDigest: sealed.digest,
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
    await expectLater(
      codec.restoreForSend(
        _untrustedStateRecord(
          sealed,
          recordId: '10000000-0000-4000-8000-000000000002',
        ),
        expectedDigest: sealed.digest,
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
    await expectLater(
      codec.restoreForSend(
        _untrustedStateRecord(sealed, keyEpoch: 6),
        expectedDigest: sealed.digest,
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
  });

  test('认证记录状态规范化双父摘要并表达显式合并', () async {
    final codec = await _createStateCodec();
    addTearDown(codec.close);
    final genesis = await codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _stateTestOperationId1,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[1]),
    );
    final firstBranch = await codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 2,
      parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
      operationId: _stateTestOperationId2,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[2]),
    );
    final secondBranch = await codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 2,
      parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
      operationId: _stateTestOperationId3,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[3]),
    );
    final merge = await codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 3,
      parentDigests: <E2eeAccountRecordStateDigest>[
        secondBranch.digest,
        firstBranch.digest,
      ],
      operationId: _stateTestOperationId4,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[4]),
    );
    final sameParentsOtherOrder = await codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 3,
      parentDigests: <E2eeAccountRecordStateDigest>[
        firstBranch.digest,
        secondBranch.digest,
      ],
      operationId: '20000000-0000-4000-8000-000000000005',
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[4]),
    );

    expect(merge.parentDigests, sameParentsOtherOrder.parentDigests);
    expect(
      merge.parentDigests,
      unorderedEquals(<Object>[firstBranch.digest, secondBranch.digest]),
    );
    final openedParents = await codec.open(
      _untrustedStateRecord(merge),
      decode: (state, _) => state.parentDigests,
    );
    expect(openedParents, merge.parentDigests);
  });

  test('认证记录状态拒绝非法版本、父集合与写入声明', () async {
    final codec = await _createStateCodec();
    addTearDown(codec.close);
    final genesis = await codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _stateTestOperationId1,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List(0),
    );
    final other = E2eeAccountRecordStateDigest.fromTrustedStorage(
      Uint8List.fromList(List<int>.filled(32, 7)),
    );

    Future<void> seal({
      required int version,
      required List<E2eeAccountRecordStateDigest> parents,
      String operationId = _stateTestOperationId2,
      String claimedWriterDeviceId = _stateTestWriterDeviceId,
      int claimedWriterKeyVersion = 1,
    }) async {
      await codec.sealValue(
        entityKey: _stateTestEntityKey,
        logicalVersion: version,
        parentDigests: parents,
        operationId: operationId,
        claimedWriterDeviceId: claimedWriterDeviceId,
        claimedWriterKeyVersion: claimedWriterKeyVersion,
        payload: Uint8List(0),
      );
    }

    await expectLater(
      seal(version: 1, parents: <E2eeAccountRecordStateDigest>[genesis.digest]),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      seal(version: 2, parents: const []),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      seal(
        version: 2,
        parents: <E2eeAccountRecordStateDigest>[genesis.digest, genesis.digest],
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      seal(
        version: 3,
        parents: <E2eeAccountRecordStateDigest>[
          genesis.digest,
          other,
          E2eeAccountRecordStateDigest.fromTrustedStorage(
            Uint8List.fromList(List<int>.filled(32, 8)),
          ),
        ],
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      seal(
        version: 2,
        parents: <E2eeAccountRecordStateDigest>[genesis.digest],
        operationId: 'ABCDEFAB-0000-4000-8000-000000000002',
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      seal(
        version: 2,
        parents: <E2eeAccountRecordStateDigest>[genesis.digest],
        claimedWriterDeviceId: '30000000-0000-3000-8000-000000000001',
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      seal(
        version: 2,
        parents: <E2eeAccountRecordStateDigest>[genesis.digest],
        claimedWriterKeyVersion: 0,
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      codec.sealValue(
        entityKey: _stateTestEntityKey,
        logicalVersion: 2,
        parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
        operationId: _stateTestOperationId2,
        claimedWriterDeviceId: _stateTestWriterDeviceId,
        claimedWriterKeyVersion: 1,
        payload: Uint8List(e2eeAccountRecordMaxCiphertextBytes),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('认证记录状态在墓碑被篡改或内层帧非法时失败关闭', () async {
    final codec = await _createStateCodec();
    addTearDown(codec.close);
    final tombstone = await codec.sealTombstone(
      entityKey: _stateTestEntityKey,
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _stateTestOperationId1,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
    );
    final tampered = Uint8List.fromList(tombstone.record.ciphertext);
    tampered[tampered.length - 1] ^= 1;
    await expectLater(
      codec.open<void>(
        _untrustedStateRecord(tombstone, ciphertext: tampered),
        decode: (_, _) {},
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );

    const core = KelivoSecureCore();
    final rawCipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: await core.generateAccountRootKey(keyEpoch: 7),
      userId: _stateTestUserId,
      currentKeyEpoch: 7,
    );
    final malformed = await rawCipher.seal(
      entityKey: _stateTestEntityKey,
      payload: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final malformedCodec = E2eeAccountRecordStateCodec.takeOwnership(rawCipher);
    addTearDown(malformedCodec.close);
    await expectLater(
      malformedCodec.open<void>(
        E2eeUntrustedAccountRecordEnvelope.fromTransport(
          recordId: E2eeUntrustedAccountRecordId.fromTransport(
            malformed.recordId.wireValue,
          ),
          envelopeVersion: e2eeAccountRecordEnvelopeVersion,
          keyEpoch: malformed.keyEpoch,
          ciphertext: malformed.ciphertext,
        ),
        decode: (_, _) {},
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('认证记录状态在解码异常或异步回调后清零借用明文', () async {
    final codec = await _createStateCodec();
    addTearDown(codec.close);
    final sealed = await codec.sealValue(
      entityKey: _stateTestEntityKey,
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _stateTestOperationId1,
      claimedWriterDeviceId: _stateTestWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[4, 5, 6]),
    );

    Uint8List? failedDecodePayload;
    await expectLater(
      codec.open<void>(
        _untrustedStateRecord(sealed),
        decode: (_, payload) {
          failedDecodePayload = payload;
          throw const FormatException('模拟领域解码失败');
        },
      ),
      throwsA(isA<FormatException>()),
    );
    expect(failedDecodePayload, everyElement(0));

    Uint8List? asynchronousPayload;
    await expectLater(
      codec.open<Object?>(
        _untrustedStateRecord(sealed),
        decode: (_, payload) {
          asynchronousPayload = payload;
          return Future<void>.value();
        },
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(asynchronousPayload, everyElement(0));
  });
}

Future<E2eeAccountRecordStateCodec> _createStateCodec() async {
  const core = KelivoSecureCore();
  return E2eeAccountRecordStateCodec.takeOwnership(
    E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: await core.generateAccountRootKey(keyEpoch: 7),
      userId: _stateTestUserId,
      currentKeyEpoch: 7,
    ),
  );
}

Uint8List _rawStateUuid(String value) {
  final hex = value.replaceAll('-', '');
  return Uint8List.fromList(<int>[
    for (var offset = 0; offset < hex.length; offset += 2)
      int.parse(hex.substring(offset, offset + 2), radix: 16),
  ]);
}

E2eeUntrustedAccountRecordEnvelope _untrustedStateRecord(
  E2eeSealedAccountRecordState state, {
  String? recordId,
  int? keyEpoch,
  Uint8List? ciphertext,
}) {
  return E2eeUntrustedAccountRecordEnvelope.fromTransport(
    recordId: E2eeUntrustedAccountRecordId.fromTransport(
      recordId ?? state.record.recordId.wireValue,
    ),
    envelopeVersion: e2eeAccountRecordEnvelopeVersion,
    keyEpoch: keyEpoch ?? state.record.keyEpoch,
    ciphertext: ciphertext ?? state.record.ciphertext,
  );
}

Iterable<SyncEntityKey> _unreadableSyncEntityKeys() sync* {
  throw StateError('仅本地执行器不应读取同步实体键');
}

final class _InterruptAfterMarkerDurability implements RestoreDurability {
  _InterruptAfterMarkerDurability({
    required this.delegate,
    required this.markerPath,
    required this.plaintextArtifactPath,
  });

  final RestoreDurability delegate;
  final String markerPath;
  final String plaintextArtifactPath;
  bool _markerRestricted = false;
  bool _markerSynced = false;
  bool _interrupted = false;
  bool markerWasDurableBeforeInterruption = false;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) async {
    await delegate.restrictFile(file);
    if (p.equals(file.path, markerPath)) {
      _markerRestricted = true;
    }
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
    if (!_interrupted &&
        await File(markerPath).exists() &&
        await File(plaintextArtifactPath).exists()) {
      _interrupted = true;
      markerWasDurableBeforeInterruption =
          _markerRestricted && _markerSynced && fullBarrier;
      throw StateError('模拟清理标记持久化后的进程中断');
    }
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    await delegate.syncFile(file, fullBarrier: fullBarrier);
    if (p.equals(file.path, markerPath) && fullBarrier) {
      _markerSynced = true;
    }
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) {
    return delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}
