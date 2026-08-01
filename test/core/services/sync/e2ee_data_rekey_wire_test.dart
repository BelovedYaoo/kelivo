import 'dart:typed_data';

import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_data_rekey_artifact_codec.dart';
import 'package:Kelivo/core/services/sync/e2ee_data_rekey_wire.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('data-rekey completion 规范帧', () {
    test('与安全核心的 270 字节固定向量逐字一致', () {
      final frame = buildE2eeDataRekeyCompletionFrame(
        E2eeDataRekeyCompletionFields(
          operationId: '11111111-1111-4111-8111-111111111111',
          userId: '22222222-2222-4222-8222-222222222222',
          issuerDeviceId: '33333333-3333-4333-8333-333333333333',
          sourceDataGeneration: 7,
          targetDataGeneration: 8,
          sourceKeyEpoch: 11,
          targetKeyEpoch: 12,
          sourceSnapshotRoot: Uint8List(32)..fillRange(0, 32, 0x44),
          sourceRecordCount: 2,
          sourceAttachmentCount: 1,
          sourceMaximumChangeSeq: 9,
          sourceRecordCursorEnd: '55555555-5555-4555-8555-555555555555',
          sourceAttachmentCursorEnd: E2eeDataRekeyAttachmentCursor(
            attachmentId: '66666666-6666-4666-8666-666666666666',
            uploadId: '77777777-7777-4777-8777-777777777777',
          ),
          membershipGeneration: 3,
          membershipManifestDigest: Uint8List(32)..fillRange(0, 32, 0x88),
          stagedRecordCount: 2,
          stagedAttachmentCount: 1,
          stagedCiphertextSetDigest: Uint8List(32)..fillRange(0, 32, 0x99),
        ),
      );

      expect(frame, orderedEquals(_hexBytes(_completionFrameHex)));
      expect(frame, hasLength(e2eeDataRekeyCompletionFrameBytes));
    });

    test('proofDigest 与 TypeScript 固定向量一致', () {
      final signature = Uint8List.fromList(
        List<int>.generate(64, (index) => index),
      );

      expect(
        digestE2eeDataRekeyCompletionProof(
          proofFrame: _hexBytes(_completionFrameHex),
          signature: signature,
        ),
        orderedEquals(_hexBytes(_proofDigestHex)),
      );
    });

    test('数量与 nullable cursor 必须成对且 source/staged 数量一致', () {
      final attachmentCursor = E2eeDataRekeyAttachmentCursor(
        attachmentId: '66666666-6666-4666-8666-666666666666',
        uploadId: '77777777-7777-4777-8777-777777777777',
      );
      final invalidFields = <E2eeDataRekeyCompletionFields Function()>[
        () => _completionFields(
          sourceRecordCount: 0,
          stagedRecordCount: 0,
          sourceRecordCursorEnd: '55555555-5555-4555-8555-555555555555',
          sourceAttachmentCursorEnd: attachmentCursor,
        ),
        () => _completionFields(
          sourceRecordCursorEnd: null,
          sourceAttachmentCursorEnd: attachmentCursor,
        ),
        () => _completionFields(
          sourceAttachmentCount: 0,
          stagedAttachmentCount: 0,
          sourceRecordCursorEnd: '55555555-5555-4555-8555-555555555555',
          sourceAttachmentCursorEnd: attachmentCursor,
        ),
        () => _completionFields(
          sourceRecordCursorEnd: '55555555-5555-4555-8555-555555555555',
          sourceAttachmentCursorEnd: null,
        ),
        () => _completionFields(
          stagedRecordCount: 1,
          sourceRecordCursorEnd: '55555555-5555-4555-8555-555555555555',
          sourceAttachmentCursorEnd: attachmentCursor,
        ),
      ];

      for (final createFields in invalidFields) {
        expect(createFields, throwsFormatException);
      }
    });
  });

  group('data-rekey 冻结源快照', () {
    test('规范子帧和排序聚合与 TypeScript 固定向量一致', () {
      final header = _sourceHeader();
      final firstRecord = _sourceRecord(
        recordId: '44444444-4444-4444-8444-444444444441',
        revision: 1,
        ciphertextBytes: 3,
        ciphertextDigest: _hexBytes(_firstCiphertextDigestHex),
        lastChangeSeq: 8,
      );
      final secondRecord = _sourceRecord(
        recordId: '44444444-4444-4444-8444-444444444442',
        revision: 2,
        ciphertextBytes: 4,
        ciphertextDigest: _hexBytes(_secondCiphertextDigestHex),
        lastChangeSeq: 9,
      );
      final attachment = _sourceAttachment();

      expect(
        buildE2eeDataRekeySourceHeader(header),
        orderedEquals(_hexBytes(_sourceHeaderHex)),
      );
      expect(
        buildE2eeDataRekeySourceRecordFrame(firstRecord),
        orderedEquals(_hexBytes(_firstSourceRecordFrameHex)),
      );
      expect(
        buildE2eeDataRekeySourceAttachmentFrame(attachment),
        orderedEquals(_hexBytes(_sourceAttachmentFrameHex)),
      );

      final snapshot = computeE2eeDataRekeySourceSnapshot(
        header: header,
        records: [secondRecord, firstRecord],
        attachments: [attachment],
      );

      expect(snapshot.root, orderedEquals(_hexBytes(_sourceSnapshotRootHex)));
      expect(snapshot.recordCount, 2);
      expect(snapshot.attachmentCount, 1);
      expect(snapshot.maximumChangeSeq, 9);
      expect(snapshot.recordCursorEnd, '44444444-4444-4444-8444-444444444442');
      expect(
        snapshot.attachmentCursorEnd?.attachmentId,
        '66666666-6666-4666-8666-666666666666',
      );
      expect(
        snapshot.attachmentCursorEnd?.uploadId,
        '77777777-7777-4777-8777-777777777777',
      );
    });

    test('空集合与 TypeScript 固定根一致且游标为空', () {
      final snapshot = computeE2eeDataRekeySourceSnapshot(
        header: E2eeDataRekeySourceHeaderFields(
          userId: '22222222-2222-4222-8222-222222222222',
          operationId: '11111111-1111-4111-8111-111111111111',
          sourceDataGeneration: 7,
          sourceKeyEpoch: 11,
          expectedRecordCount: 0,
          expectedAttachmentCount: 0,
          expectedMaximumChangeSeq: 0,
        ),
        records: const [],
        attachments: const [],
      );

      expect(
        snapshot.root,
        orderedEquals(_hexBytes(_emptySourceSnapshotRootHex)),
      );
      expect(snapshot.recordCount, 0);
      expect(snapshot.attachmentCount, 0);
      expect(snapshot.maximumChangeSeq, 0);
      expect(snapshot.recordCursorEnd, isNull);
      expect(snapshot.attachmentCursorEnd, isNull);
    });

    test('流式分页累计与批量固定向量一致', () {
      final accumulator = E2eeDataRekeySourceSnapshotAccumulator(
        _sourceHeader(),
      );
      accumulator.addRecord(
        _sourceRecord(
          recordId: '44444444-4444-4444-8444-444444444441',
          revision: 1,
          ciphertextBytes: 3,
          ciphertextDigest: _hexBytes(_firstCiphertextDigestHex),
          lastChangeSeq: 8,
        ),
      );
      accumulator.addRecord(
        _sourceRecord(
          recordId: '44444444-4444-4444-8444-444444444442',
          revision: 2,
          ciphertextBytes: 4,
          ciphertextDigest: _hexBytes(_secondCiphertextDigestHex),
          lastChangeSeq: 9,
        ),
      );
      accumulator.addAttachment(_sourceAttachment());

      final snapshot = accumulator.finish();

      expect(snapshot.root, orderedEquals(_hexBytes(_sourceSnapshotRootHex)));
      expect(snapshot.recordCount, 2);
      expect(snapshot.attachmentCount, 1);
      expect(snapshot.maximumChangeSeq, 9);
      expect(snapshot.recordCursorEnd, '44444444-4444-4444-8444-444444444442');
      expect(
        snapshot.attachmentCursorEnd?.attachmentId,
        '66666666-6666-4666-8666-666666666666',
      );
      expect(accumulator.finish, throwsStateError);
    });

    test('流式分页累计拒绝乱序、跨阶段和不完整输入', () {
      final firstRecord = _sourceRecord(
        recordId: '44444444-4444-4444-8444-444444444441',
        revision: 1,
        ciphertextBytes: 3,
        ciphertextDigest: _hexBytes(_firstCiphertextDigestHex),
        lastChangeSeq: 8,
      );
      final secondRecord = _sourceRecord(
        recordId: '44444444-4444-4444-8444-444444444442',
        revision: 2,
        ciphertextBytes: 4,
        ciphertextDigest: _hexBytes(_secondCiphertextDigestHex),
        lastChangeSeq: 9,
      );
      final incomplete = E2eeDataRekeySourceSnapshotAccumulator(_sourceHeader())
        ..addRecord(firstRecord);
      expect(incomplete.finish, throwsFormatException);
      expect(
        () => incomplete.addAttachment(_sourceAttachment()),
        throwsFormatException,
      );

      final outOfOrder = E2eeDataRekeySourceSnapshotAccumulator(_sourceHeader())
        ..addRecord(secondRecord);
      expect(() => outOfOrder.addRecord(firstRecord), throwsFormatException);

      final overflow = E2eeDataRekeySourceSnapshotAccumulator(
        E2eeDataRekeySourceHeaderFields(
          userId: '22222222-2222-4222-8222-222222222222',
          operationId: '11111111-1111-4111-8111-111111111111',
          sourceDataGeneration: 7,
          sourceKeyEpoch: 11,
          expectedRecordCount: 0,
          expectedAttachmentCount: 0,
          expectedMaximumChangeSeq: 0,
        ),
      );
      expect(() => overflow.addRecord(firstRecord), throwsFormatException);
    });

    test('重复记录游标、数量或最大 changeSeq 不一致时失败关闭', () {
      final record = _sourceRecord(
        recordId: '44444444-4444-4444-8444-444444444441',
        revision: 1,
        ciphertextBytes: 3,
        ciphertextDigest: _hexBytes(_firstCiphertextDigestHex),
        lastChangeSeq: 8,
      );
      E2eeDataRekeySourceHeaderFields header({
        required int count,
        required int maximumChangeSeq,
      }) {
        return E2eeDataRekeySourceHeaderFields(
          userId: '22222222-2222-4222-8222-222222222222',
          operationId: '11111111-1111-4111-8111-111111111111',
          sourceDataGeneration: 7,
          sourceKeyEpoch: 11,
          expectedRecordCount: count,
          expectedAttachmentCount: 0,
          expectedMaximumChangeSeq: maximumChangeSeq,
        );
      }

      expect(
        () => computeE2eeDataRekeySourceSnapshot(
          header: header(count: 2, maximumChangeSeq: 8),
          records: [record, record],
          attachments: const [],
        ),
        throwsFormatException,
      );
      expect(
        () => computeE2eeDataRekeySourceSnapshot(
          header: header(count: 0, maximumChangeSeq: 0),
          records: [record],
          attachments: const [],
        ),
        throwsFormatException,
      );
      expect(
        () => computeE2eeDataRekeySourceSnapshot(
          header: header(count: 1, maximumChangeSeq: 9),
          records: [record],
          attachments: const [],
        ),
        throwsFormatException,
      );
    });

    test('附件分块索引和总长度必须精确匹配', () {
      E2eeDataRekeySourceAttachmentChunkDigestItem chunk({
        required int index,
        required int bytes,
      }) {
        return E2eeDataRekeySourceAttachmentChunkDigestItem(
          chunkIndex: index,
          ciphertextBytes: bytes,
          ciphertextDigest: _hexBytes(_firstCiphertextDigestHex),
        );
      }

      E2eeDataRekeySourceAttachmentDigestItem create({
        required int totalBytes,
        required List<E2eeDataRekeySourceAttachmentChunkDigestItem> chunks,
      }) {
        return E2eeDataRekeySourceAttachmentDigestItem(
          attachmentId: '66666666-6666-4666-8666-666666666666',
          uploadId: '77777777-7777-4777-8777-777777777777',
          chunkKeyEpoch: 11,
          manifestKeyEpoch: 11,
          manifestRevision: 1,
          chunkCount: chunks.length,
          totalCiphertextBytes: totalBytes,
          manifestCiphertextBytes: 3,
          manifestCiphertextDigest: _hexBytes(_manifestCiphertextDigestHex),
          chunks: chunks,
        );
      }

      expect(
        () => create(totalBytes: 3, chunks: [chunk(index: 1, bytes: 3)]),
        throwsFormatException,
      );
      expect(
        () => create(totalBytes: 4, chunks: [chunk(index: 0, bytes: 3)]),
        throwsFormatException,
      );
    });
  });

  group('data-rekey 暂存密文集合', () {
    test('84 字节子帧和规范排序聚合与 TypeScript 固定向量一致', () {
      final firstRecord = E2eeDataRekeyStagedRecordDigestItem(
        sourceRecordId: '44444444-4444-4444-8444-444444444441',
        targetRecordId: '55555555-5555-4555-8555-555555555541',
        sourceRevision: 1,
        targetKeyEpoch: 12,
        envelopeVersion: 1,
        ciphertextBytes: 5,
        ciphertextDigest: _hexBytes(_firstStagedRecordDigestHex),
      );
      final secondRecord = E2eeDataRekeyStagedRecordDigestItem(
        sourceRecordId: '44444444-4444-4444-8444-444444444442',
        targetRecordId: '55555555-5555-4555-8555-555555555542',
        sourceRevision: 2,
        targetKeyEpoch: 12,
        envelopeVersion: 1,
        ciphertextBytes: 3,
        ciphertextDigest: _hexBytes(_secondStagedRecordDigestHex),
      );
      final attachment = E2eeDataRekeyStagedAttachmentDigestItem(
        attachmentId: '66666666-6666-4666-8666-666666666666',
        uploadId: '77777777-7777-4777-8777-777777777777',
        sourceManifestRevision: 1,
        manifestRevision: 2,
        manifestKeyEpoch: 12,
        manifestCiphertextBytes: 3,
        manifestCiphertextDigest: _hexBytes(_stagedManifestDigestHex),
      );

      expect(
        buildE2eeDataRekeyStagedRecordFrame(firstRecord),
        orderedEquals(_hexBytes(_firstStagedRecordFrameHex)),
      );
      expect(
        buildE2eeDataRekeyStagedAttachmentFrame(attachment),
        orderedEquals(_hexBytes(_stagedAttachmentFrameHex)),
      );
      expect(
        computeE2eeDataRekeyStagedCiphertextSetDigest(
          records: [secondRecord, firstRecord],
          attachments: [attachment],
        ),
        orderedEquals(_hexBytes(_stagedCiphertextSetDigestHex)),
      );
    });

    test('空集合与 TypeScript 固定摘要一致', () {
      expect(
        computeE2eeDataRekeyStagedCiphertextSetDigest(
          records: const [],
          attachments: const [],
        ),
        orderedEquals(_hexBytes(_emptyStagedCiphertextSetDigestHex)),
      );
    });

    test('流式暂存累计与批量固定向量一致并拒绝不完整输入', () {
      final firstRecord = E2eeDataRekeyStagedRecordDigestItem(
        sourceRecordId: '44444444-4444-4444-8444-444444444441',
        targetRecordId: '55555555-5555-4555-8555-555555555541',
        sourceRevision: 1,
        targetKeyEpoch: 12,
        envelopeVersion: 1,
        ciphertextBytes: 5,
        ciphertextDigest: _hexBytes(_firstStagedRecordDigestHex),
      );
      final secondRecord = E2eeDataRekeyStagedRecordDigestItem(
        sourceRecordId: '44444444-4444-4444-8444-444444444442',
        targetRecordId: '55555555-5555-4555-8555-555555555542',
        sourceRevision: 2,
        targetKeyEpoch: 12,
        envelopeVersion: 1,
        ciphertextBytes: 3,
        ciphertextDigest: _hexBytes(_secondStagedRecordDigestHex),
      );
      final attachment = E2eeDataRekeyStagedAttachmentDigestItem(
        attachmentId: '66666666-6666-4666-8666-666666666666',
        uploadId: '77777777-7777-4777-8777-777777777777',
        sourceManifestRevision: 1,
        manifestRevision: 2,
        manifestKeyEpoch: 12,
        manifestCiphertextBytes: 3,
        manifestCiphertextDigest: _hexBytes(_stagedManifestDigestHex),
      );
      final accumulator =
          E2eeDataRekeyStagedCiphertextSetAccumulator(
              expectedRecordCount: 2,
              expectedAttachmentCount: 1,
            )
            ..addRecord(firstRecord)
            ..addRecord(secondRecord)
            ..addAttachment(attachment);

      expect(
        accumulator.finish(),
        orderedEquals(_hexBytes(_stagedCiphertextSetDigestHex)),
      );
      expect(accumulator.finish, throwsStateError);

      final incomplete = E2eeDataRekeyStagedCiphertextSetAccumulator(
        expectedRecordCount: 2,
        expectedAttachmentCount: 0,
      )..addRecord(firstRecord);
      expect(incomplete.finish, throwsFormatException);
      expect(() => incomplete.addAttachment(attachment), throwsFormatException);
    });

    test('重复记录和附件游标失败关闭', () {
      final record = E2eeDataRekeyStagedRecordDigestItem(
        sourceRecordId: '44444444-4444-4444-8444-444444444441',
        targetRecordId: '55555555-5555-4555-8555-555555555541',
        sourceRevision: 1,
        targetKeyEpoch: 12,
        envelopeVersion: 1,
        ciphertextBytes: 5,
        ciphertextDigest: _hexBytes(_firstStagedRecordDigestHex),
      );
      final attachment = E2eeDataRekeyStagedAttachmentDigestItem(
        attachmentId: '66666666-6666-4666-8666-666666666666',
        uploadId: '77777777-7777-4777-8777-777777777777',
        sourceManifestRevision: 1,
        manifestRevision: 2,
        manifestKeyEpoch: 12,
        manifestCiphertextBytes: 3,
        manifestCiphertextDigest: _hexBytes(_stagedManifestDigestHex),
      );

      expect(
        () => computeE2eeDataRekeyStagedCiphertextSetDigest(
          records: [record, record],
          attachments: const [],
        ),
        throwsFormatException,
      );
      expect(
        () => computeE2eeDataRekeyStagedCiphertextSetDigest(
          records: const [],
          attachments: [attachment, attachment],
        ),
        throwsFormatException,
      );
    });
  });

  group('data-rekey 密文摘要', () {
    test('仅从本地非空密文字节计算 SHA-256', () {
      expect(
        digestE2eeDataRekeyCiphertext(Uint8List.fromList([1, 2, 3])),
        orderedEquals(_hexBytes(_firstCiphertextDigestHex)),
      );
      expect(
        () => digestE2eeDataRekeyCiphertext(Uint8List(0)),
        throwsFormatException,
      );
    });
  });

  group('data-rekey 严格边界与篡改隔离', () {
    test('接受 uint32 与安全 uint64 上界并拒绝越界值', () {
      final record = E2eeDataRekeySourceRecordDigestItem(
        recordId: '44444444-4444-4444-8444-444444444441',
        revision: 0xffffffff,
        envelopeVersion: 0xffffffff,
        keyEpoch: 0xffffffff,
        ciphertextBytes: 9007199254740991,
        ciphertextDigest: Uint8List(32),
        lastChangeSeq: 9007199254740991,
      );
      expect(
        buildE2eeDataRekeySourceRecordFrame(record),
        hasLength(e2eeDataRekeySourceRecordFrameBytes),
      );
      expect(
        () => E2eeDataRekeySourceAttachmentChunkDigestItem(
          chunkIndex: 0x100000000,
          ciphertextBytes: 1,
          ciphertextDigest: Uint8List(32),
        ),
        throwsFormatException,
      );
      expect(
        () => E2eeDataRekeySourceAttachmentChunkDigestItem(
          chunkIndex: 0,
          ciphertextBytes: 9007199254740992,
          ciphertextDigest: Uint8List(32),
        ),
        throwsFormatException,
      );
      expect(
        () => E2eeDataRekeySourceAttachmentChunkDigestItem(
          chunkIndex: -1,
          ciphertextBytes: 1,
          ciphertextDigest: Uint8List(32),
        ),
        throwsFormatException,
      );
    });

    test('拒绝非规范 UUID、摘要长度和证明长度或域', () {
      expect(
        () => E2eeDataRekeyAttachmentCursor(
          attachmentId: '66666666-6666-4666-8666-66666666666A',
          uploadId: '77777777-7777-4777-8777-777777777777',
        ),
        throwsFormatException,
      );
      expect(
        () => E2eeDataRekeySourceAttachmentChunkDigestItem(
          chunkIndex: 0,
          ciphertextBytes: 1,
          ciphertextDigest: Uint8List(31),
        ),
        throwsFormatException,
      );
      expect(
        () => digestE2eeDataRekeyCompletionProof(
          proofFrame: Uint8List(e2eeDataRekeyCompletionFrameBytes - 1),
          signature: Uint8List(e2eeDataRekeyCompletionSignatureBytes),
        ),
        throwsFormatException,
      );
      expect(
        () => digestE2eeDataRekeyCompletionProof(
          proofFrame: _hexBytes(_completionFrameHex),
          signature: Uint8List(e2eeDataRekeyCompletionSignatureBytes - 1),
        ),
        throwsFormatException,
      );
      final invalidDomain = _hexBytes(_completionFrameHex)..[0] ^= 1;
      expect(
        () => digestE2eeDataRekeyCompletionProof(
          proofFrame: invalidDomain,
          signature: Uint8List(e2eeDataRekeyCompletionSignatureBytes),
        ),
        throwsFormatException,
      );
    });

    test('构造时复制输入且公开字节不可修改', () {
      final inputDigest = _hexBytes(_firstStagedRecordDigestHex);
      final item = E2eeDataRekeyStagedRecordDigestItem(
        sourceRecordId: '44444444-4444-4444-8444-444444444441',
        targetRecordId: '55555555-5555-4555-8555-555555555541',
        sourceRevision: 1,
        targetKeyEpoch: 12,
        envelopeVersion: 1,
        ciphertextBytes: 5,
        ciphertextDigest: inputDigest,
      );
      inputDigest[0] ^= 1;
      final frame = buildE2eeDataRekeyStagedRecordFrame(item);

      expect(frame, orderedEquals(_hexBytes(_firstStagedRecordFrameHex)));
      expect(() => item.ciphertextDigest[0] ^= 1, throwsUnsupportedError);
      expect(() => frame[0] ^= 1, throwsUnsupportedError);
    });

    test('证明非域字段篡改会改变 proofDigest', () {
      final signature = Uint8List.fromList(
        List<int>.generate(64, (index) => index),
      );
      final tamperedFrame = _hexBytes(_completionFrameHex)
        ..[e2eeDataRekeyCompletionFrameBytes - 1] ^= 1;

      expect(
        digestE2eeDataRekeyCompletionProof(
          proofFrame: tamperedFrame,
          signature: signature,
        ),
        isNot(orderedEquals(_hexBytes(_proofDigestHex))),
      );
    });
  });

  group('data-rekey 最终校验进度', () {
    test('接受与 finalize 请求绑定的跨请求检查点', () {
      final request = _finalizeRequest();

      final outcome =
          CloudSyncDataRekeyFinalizeOutcome.fromJson(<String, Object?>{
            'result': 'verification-pending',
            'operationId': request.activeLease.operation.operationId,
            'phase': 'staged-records',
            'sourceRecordCount': 2,
            'sourceAttachmentCount': 1,
            'stagedRecordCount': 1,
            'stagedAttachmentCount': 0,
          }, request: request);

      expect(outcome, isA<CloudSyncDataRekeyFinalizePending>());
      final pending = outcome as CloudSyncDataRekeyFinalizePending;
      expect(
        pending.phase,
        CloudSyncDataRekeyFinalizeVerificationPhase.stagedRecords,
      );
      expect(pending.stagedRecordCount, 1);
    });

    test('拒绝越过前置阶段或超出证明数量的检查点', () {
      final request = _finalizeRequest();
      for (final progress in <CloudSyncJsonMap>[
        <String, Object?>{
          'result': 'verification-pending',
          'operationId': request.activeLease.operation.operationId,
          'phase': 'staged-records',
          'sourceRecordCount': 1,
          'sourceAttachmentCount': 1,
          'stagedRecordCount': 1,
          'stagedAttachmentCount': 0,
        },
        <String, Object?>{
          'result': 'verification-pending',
          'operationId': request.activeLease.operation.operationId,
          'phase': 'verified',
          'sourceRecordCount': 2,
          'sourceAttachmentCount': 1,
          'stagedRecordCount': 3,
          'stagedAttachmentCount': 1,
        },
      ]) {
        expect(
          () => CloudSyncDataRekeyFinalizeOutcome.fromJson(
            progress,
            request: request,
          ),
          throwsFormatException,
        );
      }
    });
  });

  group('data-rekey 耐久 stage artifact', () {
    test('记录 pending 可精确重建请求且 confirmed 仅保留规范摘要字段', () {
      final binding = _artifactBinding();
      final pending = E2eeDataRekeyPendingRecordArtifact(
        binding: binding,
        activeLease: _artifactLease(binding),
        mutationId: '44444444-4444-4444-8444-444444444444',
        sourceRecordId: '55555555-5555-4555-8555-555555555555',
        targetRecordId: '66666666-6666-4666-8666-666666666666',
        sourceRevision: 9,
        ciphertext: Uint8List.fromList(<int>[1, 2, 3, 4]),
      );

      final decoded = E2eeDataRekeyStageArtifact.decode(
        pending.encode(),
        expectedBinding: binding,
      );
      expect(decoded, isA<E2eeDataRekeyPendingRecordArtifact>());
      final replay = decoded as E2eeDataRekeyPendingRecordArtifact;
      expect(replay.request.mutationId, pending.request.mutationId);
      expect(
        replay.request.activeLease.leaseToken,
        '33333333-3333-4333-8333-333333333333',
      );
      expect(replay.request.targetRecordId, pending.request.targetRecordId);
      expect(replay.request.ciphertext, pending.request.ciphertext);

      final confirmed = pending.confirm(
        CloudSyncDataRekeyRecordStageResult.fromJson(<String, Object?>{
          'result': 'staged',
          'operationId': binding.operation.operationId,
          'mutationId': pending.request.mutationId,
          'sourceRecordId': pending.request.sourceRecordId,
          'targetRecordId': pending.request.targetRecordId,
          'leaseVersion': pending.activeLease.leaseVersion,
        }, request: pending.request),
      );
      final confirmedBytes = confirmed.encode();
      expect(confirmedBytes.length, lessThan(1024));
      final restored = E2eeDataRekeyStageArtifact.decode(
        confirmedBytes,
        expectedBinding: binding,
      );
      expect(restored, isA<E2eeDataRekeyConfirmedRecordArtifact>());
      final restoredRecord = restored as E2eeDataRekeyConfirmedRecordArtifact;
      expect(
        buildE2eeDataRekeyStagedRecordFrame(restoredRecord.digestItem),
        buildE2eeDataRekeyStagedRecordFrame(confirmed.digestItem),
      );
    });

    test('附件 confirmed 只提升 manifest 代次并保留原附件身份', () {
      final binding = _artifactBinding();
      final pending = E2eeDataRekeyPendingAttachmentArtifact(
        binding: binding,
        activeLease: _artifactLease(binding),
        mutationId: '77777777-7777-4777-8777-777777777777',
        attachmentId: '88888888-8888-4888-8888-888888888888',
        uploadId: '99999999-9999-4999-8999-999999999999',
        sourceManifestRevision: 4,
        manifestCiphertext: Uint8List.fromList(<int>[8, 9, 10]),
      );

      final confirmed = pending.confirm(
        CloudSyncDataRekeyAttachmentStageResult.fromJson(<String, Object?>{
          'result': 'staged',
          'operationId': binding.operation.operationId,
          'mutationId': pending.request.mutationId,
          'attachmentId': pending.request.attachmentId,
          'uploadId': pending.request.uploadId,
          'manifestRevision': pending.request.manifestRevision,
          'leaseVersion': pending.activeLease.leaseVersion,
        }, request: pending.request),
      );
      final restored = E2eeDataRekeyStageArtifact.decode(
        confirmed.encode(),
        expectedBinding: binding,
      );
      expect(restored, isA<E2eeDataRekeyConfirmedAttachmentArtifact>());
      final attachment = restored as E2eeDataRekeyConfirmedAttachmentArtifact;
      expect(attachment.digestItem.attachmentId, pending.request.attachmentId);
      expect(attachment.digestItem.uploadId, pending.request.uploadId);
      expect(attachment.digestItem.sourceManifestRevision, 4);
      expect(attachment.digestItem.manifestRevision, 5);
      expect(attachment.digestItem.manifestKeyEpoch, 12);
    });

    test('解码拒绝跨账户、issuer 或 operation 使用缓存', () {
      final binding = _artifactBinding();
      final pending = E2eeDataRekeyPendingRecordArtifact(
        binding: binding,
        activeLease: _artifactLease(binding),
        mutationId: '44444444-4444-4444-8444-444444444444',
        sourceRecordId: '55555555-5555-4555-8555-555555555555',
        targetRecordId: '66666666-6666-4666-8666-666666666666',
        sourceRevision: 9,
        ciphertext: Uint8List.fromList(<int>[1]),
      );
      final foreignBinding = E2eeDataRekeyArtifactBinding(
        userId: binding.userId,
        issuerDeviceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        operation: binding.operation,
      );

      expect(
        () => E2eeDataRekeyStageArtifact.decode(
          pending.encode(),
          expectedBinding: foreignBinding,
        ),
        throwsFormatException,
      );
      expect(
        () => E2eeDataRekeyStageArtifact.decode(
          Uint8List.fromList(<int>[0x20, ...pending.encode()]),
          expectedBinding: binding,
        ),
        throwsFormatException,
      );
    });
  });
}

E2eeDataRekeyArtifactBinding _artifactBinding() {
  return E2eeDataRekeyArtifactBinding(
    userId: '11111111-1111-4111-8111-111111111111',
    issuerDeviceId: '22222222-2222-4222-8222-222222222222',
    operation: CloudSyncDataRekeyOperationScope(
      operationId: 'aaaaaaaa-1111-4111-8111-111111111111',
      sourceDataGeneration: 7,
      sourceKeyEpoch: 11,
      targetKeyEpoch: 12,
    ),
  );
}

CloudSyncDataRekeyActiveLease _artifactLease(
  E2eeDataRekeyArtifactBinding binding,
) {
  return CloudSyncDataRekeyActiveLease(
    operation: binding.operation,
    leaseToken: '33333333-3333-4333-8333-333333333333',
    leaseVersion: 5,
  );
}

CloudSyncDataRekeyFinalizeRequest _finalizeRequest() {
  return CloudSyncDataRekeyFinalizeRequest(
    activeLease: CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: '11111111-1111-4111-8111-111111111111',
        sourceDataGeneration: 7,
        sourceKeyEpoch: 11,
        targetKeyEpoch: 12,
      ),
      leaseToken: '22222222-2222-4222-8222-222222222222',
      leaseVersion: 3,
    ),
    mutationId: '33333333-3333-4333-8333-333333333333',
    proof: CloudSyncDataRekeyFinalizeProof(
      issuerDeviceId: '44444444-4444-4444-8444-444444444444',
      sourceSnapshotRoot: Uint8List(32),
      sourceRecordCount: 2,
      sourceAttachmentCount: 1,
      sourceMaximumChangeSeq: 9,
      sourceRecordCursorEnd: '55555555-5555-4555-8555-555555555555',
      sourceAttachmentCursorEnd: CloudSyncDataRekeyAttachmentCursor(
        attachmentId: '66666666-6666-4666-8666-666666666666',
        uploadId: '77777777-7777-4777-8777-777777777777',
      ),
      membershipGeneration: 3,
      membershipManifestDigest: Uint8List(32),
      stagedRecordCount: 2,
      stagedAttachmentCount: 1,
      stagedCiphertextSetDigest: Uint8List(32),
      signature: Uint8List(64),
    ),
  );
}

E2eeDataRekeyCompletionFields _completionFields({
  int sourceRecordCount = 2,
  int sourceAttachmentCount = 1,
  int stagedRecordCount = 2,
  int stagedAttachmentCount = 1,
  required String? sourceRecordCursorEnd,
  required E2eeDataRekeyAttachmentCursor? sourceAttachmentCursorEnd,
}) {
  return E2eeDataRekeyCompletionFields(
    operationId: '11111111-1111-4111-8111-111111111111',
    userId: '22222222-2222-4222-8222-222222222222',
    issuerDeviceId: '33333333-3333-4333-8333-333333333333',
    sourceDataGeneration: 7,
    targetDataGeneration: 8,
    sourceKeyEpoch: 11,
    targetKeyEpoch: 12,
    sourceSnapshotRoot: Uint8List(32)..fillRange(0, 32, 0x44),
    sourceRecordCount: sourceRecordCount,
    sourceAttachmentCount: sourceAttachmentCount,
    sourceMaximumChangeSeq: 9,
    sourceRecordCursorEnd: sourceRecordCursorEnd,
    sourceAttachmentCursorEnd: sourceAttachmentCursorEnd,
    membershipGeneration: 3,
    membershipManifestDigest: Uint8List(32)..fillRange(0, 32, 0x88),
    stagedRecordCount: stagedRecordCount,
    stagedAttachmentCount: stagedAttachmentCount,
    stagedCiphertextSetDigest: Uint8List(32)..fillRange(0, 32, 0x99),
  );
}

E2eeDataRekeySourceHeaderFields _sourceHeader() {
  return E2eeDataRekeySourceHeaderFields(
    userId: '22222222-2222-4222-8222-222222222222',
    operationId: '11111111-1111-4111-8111-111111111111',
    sourceDataGeneration: 7,
    sourceKeyEpoch: 11,
    expectedRecordCount: 2,
    expectedAttachmentCount: 1,
    expectedMaximumChangeSeq: 9,
  );
}

E2eeDataRekeySourceRecordDigestItem _sourceRecord({
  required String recordId,
  required int revision,
  required int ciphertextBytes,
  required Uint8List ciphertextDigest,
  required int lastChangeSeq,
}) {
  return E2eeDataRekeySourceRecordDigestItem(
    recordId: recordId,
    revision: revision,
    envelopeVersion: 1,
    keyEpoch: 11,
    ciphertextBytes: ciphertextBytes,
    ciphertextDigest: ciphertextDigest,
    lastChangeSeq: lastChangeSeq,
  );
}

E2eeDataRekeySourceAttachmentDigestItem _sourceAttachment() {
  return E2eeDataRekeySourceAttachmentDigestItem(
    attachmentId: '66666666-6666-4666-8666-666666666666',
    uploadId: '77777777-7777-4777-8777-777777777777',
    chunkKeyEpoch: 11,
    manifestKeyEpoch: 11,
    manifestRevision: 1,
    chunkCount: 2,
    totalCiphertextBytes: 7,
    manifestCiphertextBytes: 3,
    manifestCiphertextDigest: _hexBytes(_manifestCiphertextDigestHex),
    chunks: [
      E2eeDataRekeySourceAttachmentChunkDigestItem(
        chunkIndex: 0,
        ciphertextBytes: 3,
        ciphertextDigest: _hexBytes(_firstCiphertextDigestHex),
      ),
      E2eeDataRekeySourceAttachmentChunkDigestItem(
        chunkIndex: 1,
        ciphertextBytes: 4,
        ciphertextDigest: _hexBytes(_secondCiphertextDigestHex),
      ),
    ],
  );
}

Uint8List _hexBytes(String value) {
  return Uint8List.fromList([
    for (var index = 0; index < value.length; index += 2)
      int.parse(value.substring(index, index + 2), radix: 16),
  ]);
}

const _completionFrameHex =
    '6b656c69766f2d646174612d72656b65792d636f6d706c6574696f6e2d763200'
    '1111111111114111811111111111111122222222222242228222222222222222'
    '3333333333334333833333333333333300000007000000080000000b0000000c'
    '4444444444444444444444444444444444444444444444444444444444444444'
    '000000020000000100000000000000090155555555555545558555555555555555'
    '016666666666664666866666666666666677777777777747778777777777777777'
    '0000000388888888888888888888888888888888888888888888888888888888'
    '8888888800000002000000019999999999999999999999999999999999999999'
    '999999999999999999999999';
const _proofDigestHex =
    '92a1de438d228549a11fbc72794bc9612b1094197921429cc44d4a8380479a32';

const _firstCiphertextDigestHex =
    '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81';
const _secondCiphertextDigestHex =
    '6ff2c765a84cd1cb50960c12d9c436bac1260375f05fa967e2903197f66c4220';
const _manifestCiphertextDigestHex =
    '787c798e39a5bc1910355bae6d0cd87a36b2e10fd0202a83e3bb6b005da83472';
const _sourceHeaderHex =
    '6b656c69766f2d646174612d72656b65792d736f757263652d736e617073686f742d763200'
    '2222222222224222822222222222222211111111111141118111111111111111'
    '000000070000000b00000002000000010000000000000009';
const _firstSourceRecordFrameHex =
    '014444444444444444844444444444444100000001000000010000000b'
    '0000000000000003039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced528'
    '7d84a1a2011cfb810000000000000008';
const _sourceAttachmentFrameHex =
    '6666666666664666866666666666666677777777777747778777777777777777'
    '0000000b0000000b000000010000000200000000000000070000000000000003'
    '787c798e39a5bc1910355bae6d0cd87a36b2e10fd0202a83e3bb6b005da83472'
    '000000000000000000000003039058c6f2c0cb492c533b0a4d14ef77cc0f78ab'
    'ccced5287d84a1a2011cfb810000000100000000000000046ff2c765a84cd1cb'
    '50960c12d9c436bac1260375f05fa967e2903197f66c4220';
const _sourceSnapshotRootHex =
    'c8babeb3edcd31a34e58c0f749fa80e22af1ee40e0113e5d4b9da575b55fa3d5';
const _emptySourceSnapshotRootHex =
    '5293937d1f446f9470adfc9501a1bfa34f1d186e251d57c92544a6980e6c4e5d';
const _firstStagedRecordDigestHex =
    '56849622cb00996b3f965f5964416f1cc606be6d5561512970dc119d9a3a5a7d';
const _secondStagedRecordDigestHex =
    'c9e0f2aeea4897312ca3ff7900849dceebd81a8ed6dec3882954f6a9a03ebd27';
const _stagedManifestDigestHex =
    '88d5bbad1571bffc781cf587ee121e8b228da92997a0e16688ecc67a90ef41f4';
const _firstStagedRecordFrameHex =
    '4444444444444444844444444444444155555555555545558555555555555541'
    '000000010000000c00000001000000000000000556849622cb00996b3f965f59'
    '64416f1cc606be6d5561512970dc119d9a3a5a7d';
const _stagedAttachmentFrameHex =
    '6666666666664666866666666666666677777777777747778777777777777777'
    '00000001000000020000000c000000000000000388d5bbad1571bffc781cf587'
    'ee121e8b228da92997a0e16688ecc67a90ef41f4';
const _stagedCiphertextSetDigestHex =
    'de02a0cddd72f4f869b9c29a49360d6b07a4484d4614f1fedd86f9d99673fb87';
const _emptyStagedCiphertextSetDigestHex =
    '8f21d3300fbf3f6ea5bf90087a2b44bdf7b9d2e6b461c328be0f959d450022a0';
