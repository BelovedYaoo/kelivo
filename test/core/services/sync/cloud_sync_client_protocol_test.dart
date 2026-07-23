import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_record_types.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';

const _mutationId1 = '00000000-0000-4000-8000-000000000001';
const _mutationId2 = '00000000-0000-4000-8000-000000000002';
const _mutationId3 = '00000000-0000-4000-8000-000000000003';
const _recordId1 = '10000000-0000-4000-8000-000000000001';
const _recordId2 = '10000000-0000-4000-8000-000000000002';
const _recordId3 = '10000000-0000-4000-8000-000000000003';
const _deviceId1 = '20000000-0000-4000-8000-000000000001';

void main() {
  test('生产客户端固定使用官方服务地址', () {
    final client = CloudSyncClient();
    addTearDown(() => client.close(force: true));

    expect(client.baseUrl, 'https://kelivo.bemylover.top');
    expect(client.baseUrl, defaultCloudSyncBaseUrl);
  });

  test('同步服务响应重定向时拒绝访问目标地址', () async {
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var targetRequestCount = 0;
    final targetSubscription = target.listen((request) async {
      targetRequestCount++;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'service': 'kelivo-api',
            'status': 'ok',
            'timestamp': '2026-07-19T05:00:00.000Z',
          },
        }),
      );
      await request.response.close();
    });

    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final originSubscription = origin.listen((request) async {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(
          HttpHeaders.locationHeader,
          'http://${target.address.address}:${target.port}'
          '/api/system/health/get',
        );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${origin.address.address}:${origin.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await originSubscription.cancel();
      await targetSubscription.cancel();
      await origin.close(force: true);
      await target.close(force: true);
    });

    await expectLater(
      client.health(),
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having(
              (error) => error.statusCode,
              'statusCode',
              HttpStatus.found,
            ),
      ),
    );
    expect(targetRequestCount, 0);
  });

  test('v3 推送以不透明 put 和 delete 提交并解析三类结果', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pushFuture = client.pushRecords(<CloudSyncRecordMutation>[
      const CloudSyncPutRecordMutation(
        mutationId: _mutationId1,
        recordId: _recordId1,
        expectedRevision: 0,
        keyEpoch: 7,
        ciphertext: 'AQID',
      ),
      const CloudSyncDeleteRecordMutation(
        mutationId: _mutationId2,
        recordId: _recordId2,
        expectedRevision: 3,
      ),
      const CloudSyncPutRecordMutation(
        mutationId: _mutationId3,
        recordId: _recordId3,
        expectedRevision: 2,
        keyEpoch: 8,
        ciphertext: 'BAUG',
      ),
    ]);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/record/push');
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{
        'mutations': <Object?>[
          <String, Object?>{
            'mutationId': _mutationId1,
            'recordId': _recordId1,
            'expectedRevision': 0,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 7,
            'ciphertext': 'AQID',
          },
          <String, Object?>{
            'mutationId': _mutationId2,
            'recordId': _recordId2,
            'expectedRevision': 3,
            'operation': 'delete',
          },
          <String, Object?>{
            'mutationId': _mutationId3,
            'recordId': _recordId3,
            'expectedRevision': 2,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 8,
            'ciphertext': 'BAUG',
          },
        ],
      },
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'mutationId': _mutationId1,
              'status': 'applied',
              'revision': 1,
              'changeSeq': 11,
            },
            <String, Object?>{
              'mutationId': _mutationId2,
              'status': 'conflict',
              'currentRevision': 4,
            },
            <String, Object?>{
              'mutationId': _mutationId3,
              'status': 'rejected',
              'errorCode': 'SYNC_RECORD_REJECTED',
            },
          ],
        },
      }),
    );
    await request.response.close();

    final results = await pushFuture;
    expect(
      results[0],
      isA<CloudSyncAppliedMutationResult>()
          .having((result) => result.revision, 'revision', 1)
          .having((result) => result.changeSeq, 'changeSeq', 11),
    );
    expect(
      results[1],
      isA<CloudSyncConflictMutationResult>().having(
        (result) => result.currentRevision,
        'currentRevision',
        4,
      ),
    );
    expect(
      results[2],
      isA<CloudSyncRejectedMutationResult>().having(
        (result) => result.errorCode,
        'errorCode',
        'SYNC_RECORD_REJECTED',
      ),
    );
  });

  test('v3 增量拉取保持密文不透明并区分 put 与 delete', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges(cursor: 'cursor-1', limit: 2);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/change/pull');
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'cursor': 'cursor-1', 'limit': 2},
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'changeSeq': 12,
              'operation': 'put',
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'AQID',
              'ciphertextBytes': 3,
              'deletedAt': null,
              'updatedAt': '2026-07-19T05:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
            },
            <String, Object?>{
              'changeSeq': 13,
              'operation': 'delete',
              'recordId': _recordId2,
              'revision': 4,
              'envelopeVersion': null,
              'keyEpoch': null,
              'ciphertext': null,
              'ciphertextBytes': 0,
              'deletedAt': '2026-07-19T05:01:00.000Z',
              'updatedAt': '2026-07-19T05:01:00.000Z',
              'updatedByDeviceId': null,
            },
          ],
          'nextCursor': 'cursor-2',
          'hasMore': true,
          'resetRequired': false,
        },
      }),
    );
    await request.response.close();

    final page = await pullFuture;
    expect(page.nextCursor, 'cursor-2');
    expect(page.hasMore, isTrue);
    expect(page.resetRequired, isFalse);
    expect(
      page.changes[0],
      isA<CloudSyncPutRecordChange>()
          .having((change) => change.changeSeq, 'changeSeq', 12)
          .having((change) => change.recordId, 'recordId', _recordId1)
          .having((change) => change.revision, 'revision', 2)
          .having((change) => change.envelopeVersion, 'envelopeVersion', 1)
          .having((change) => change.keyEpoch, 'keyEpoch', 7)
          .having((change) => change.ciphertext, 'ciphertext', 'AQID')
          .having(
            (change) => change.updatedByDeviceId,
            'updatedByDeviceId',
            _deviceId1,
          ),
    );
    expect(
      page.changes[1],
      isA<CloudSyncDeleteRecordChange>()
          .having((change) => change.changeSeq, 'changeSeq', 13)
          .having(
            (change) => change.deletedAt,
            'deletedAt',
            DateTime.utc(2026, 7, 19, 5, 1),
          ),
    );
  });

  test('v3 增量拉取显式返回服务端要求重置游标', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges();
    final request = await requestFuture;
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'limit': 10},
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'changes': <Object?>[],
          'nextCursor': 'reset-cursor',
          'hasMore': false,
          'resetRequired': true,
        },
      }),
    );
    await request.response.close();

    final page = await pullFuture;
    expect(page.changes, isEmpty);
    expect(page.nextCursor, 'reset-cursor');
    expect(page.hasMore, isFalse);
    expect(page.resetRequired, isTrue);
  });

  test('v3 快照拉取解析 active 与 deleted 并返回固定水位游标', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullSnapshot(
      snapshotCursor: 'snapshot-1',
      limit: 2,
    );

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/snapshot/pull');
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'snapshotCursor': 'snapshot-1', 'limit': 2},
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'records': <Object?>[
            <String, Object?>{
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'BAUG',
              'ciphertextBytes': 3,
              'deletedAt': null,
              'updatedAt': '2026-07-19T05:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
              'lastChangeSeq': 12,
            },
            <String, Object?>{
              'recordId': _recordId2,
              'revision': 4,
              'envelopeVersion': null,
              'keyEpoch': null,
              'ciphertext': null,
              'ciphertextBytes': 0,
              'deletedAt': '2026-07-19T05:01:00.000Z',
              'updatedAt': '2026-07-19T05:01:00.000Z',
              'updatedByDeviceId': null,
              'lastChangeSeq': 13,
            },
          ],
          'nextSnapshotCursor': null,
          'syncCursor': 'sync-13',
          'hasMore': false,
        },
      }),
    );
    await request.response.close();

    final page = await pullFuture;
    expect(page.nextSnapshotCursor, isNull);
    expect(page.syncCursor, 'sync-13');
    expect(page.hasMore, isFalse);
    expect(
      page.records[0],
      isA<CloudSyncActiveRecord>()
          .having((record) => record.recordId, 'recordId', _recordId1)
          .having((record) => record.revision, 'revision', 2)
          .having((record) => record.lastChangeSeq, 'lastChangeSeq', 12)
          .having((record) => record.envelopeVersion, 'envelopeVersion', 1)
          .having((record) => record.keyEpoch, 'keyEpoch', 7)
          .having((record) => record.ciphertext, 'ciphertext', 'BAUG'),
    );
    expect(
      page.records[1],
      isA<CloudSyncDeletedRecord>()
          .having((record) => record.recordId, 'recordId', _recordId2)
          .having((record) => record.lastChangeSeq, 'lastChangeSeq', 13)
          .having(
            (record) => record.deletedAt,
            'deletedAt',
            DateTime.utc(2026, 7, 19, 5, 1),
          ),
    );
  });

  test('v3 推送在发网前拒绝非法标识、密文与批量边界', () {
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    addTearDown(() => client.close(force: true));
    final oversizedCiphertext = base64Url
        .encode(Uint8List(1048577))
        .replaceAll('=', '');
    final halfBatchCiphertext = base64Url
        .encode(Uint8List(524289))
        .replaceAll('=', '');
    final oversizedBatch = List<CloudSyncRecordMutation>.generate(
      11,
      (index) => CloudSyncDeleteRecordMutation(
        mutationId:
            '00000000-0000-4000-8000-${(index + 100).toString().padLeft(12, '0')}',
        recordId:
            '10000000-0000-4000-8000-${(index + 100).toString().padLeft(12, '0')}',
        expectedRevision: 1,
      ),
    );
    final invalidCalls = <(String, Object? Function())>[
      ('空批次', () => client.pushRecords(const <CloudSyncRecordMutation>[])),
      ('超过十条', () => client.pushRecords(oversizedBatch)),
      (
        '非规范 UUID',
        () => client.pushRecords(const <CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: 'A0000000-0000-4000-8000-000000000001',
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: 'AQID',
          ),
        ]),
      ),
      (
        '带填充 Base64URL',
        () => client.pushRecords(const <CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: 'AQID=',
          ),
        ]),
      ),
      (
        '非规范尾位 Base64URL',
        () => client.pushRecords(const <CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: 'AB',
          ),
        ]),
      ),
      (
        '单条密文超过一 MiB',
        () => client.pushRecords(<CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: oversizedCiphertext,
          ),
        ]),
      ),
      (
        '批次密文总量超过一 MiB',
        () => client.pushRecords(<CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: halfBatchCiphertext,
          ),
          CloudSyncPutRecordMutation(
            mutationId: _mutationId2,
            recordId: _recordId2,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: halfBatchCiphertext,
          ),
        ]),
      ),
      (
        'delete 不允许零 revision',
        () => client.pushRecords(const <CloudSyncRecordMutation>[
          CloudSyncDeleteRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
          ),
        ]),
      ),
      (
        'key epoch 越界',
        () => client.pushRecords(const <CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 2147483648,
            ciphertext: 'AQID',
          ),
        ]),
      ),
    ];

    for (final invalidCall in invalidCalls) {
      expect(
        invalidCall.$2,
        throwsA(
          isA<CloudSyncException>()
              .having(
                (error) => error.kind,
                'kind',
                CloudSyncFailureKind.validation,
              )
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
        reason: invalidCall.$1,
      );
    }
  });

  test('v3 拉取在发网前拒绝非法分页与游标边界', () {
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    addTearDown(() => client.close(force: true));
    final oversizedCursor = List<String>.filled(4097, 'a').join();
    final invalidCalls = <(String, Object? Function())>[
      ('增量 limit 下界', () => client.pullChanges(limit: 0)),
      ('增量 limit 上界', () => client.pullChanges(limit: 11)),
      ('增量空游标', () => client.pullChanges(cursor: '')),
      ('增量超长游标', () => client.pullChanges(cursor: oversizedCursor)),
      ('快照 limit 下界', () => client.pullSnapshot(limit: 0)),
      ('快照 limit 上界', () => client.pullSnapshot(limit: 11)),
      ('快照空游标', () => client.pullSnapshot(snapshotCursor: '')),
      ('快照超长游标', () => client.pullSnapshot(snapshotCursor: oversizedCursor)),
    ];

    for (final invalidCall in invalidCalls) {
      expect(
        invalidCall.$2,
        throwsA(
          isA<CloudSyncException>().having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.validation,
          ),
        ),
        reason: invalidCall.$1,
      );
    }
  });

  test('v3 拒绝密文长度、分页数量或最终水位无效的响应', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var changeRequestCount = 0;
    final subscription = server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/sync/change/pull') {
        changeRequestCount++;
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'changes': <Object?>[
                <String, Object?>{
                  'changeSeq': 12,
                  'operation': 'put',
                  'recordId': _recordId1,
                  'revision': 2,
                  'envelopeVersion': 1,
                  'keyEpoch': 7,
                  'ciphertext': 'AQID',
                  'ciphertextBytes': changeRequestCount == 1 ? 4 : 3,
                  'deletedAt': null,
                  'updatedAt': '2026-07-19T05:00:00.000Z',
                  'updatedByDeviceId': _deviceId1,
                },
                if (changeRequestCount > 1)
                  <String, Object?>{
                    'changeSeq': 13,
                    'operation': 'delete',
                    'recordId': _recordId2,
                    'revision': 4,
                    'envelopeVersion': null,
                    'keyEpoch': null,
                    'ciphertext': null,
                    'ciphertextBytes': 0,
                    'deletedAt': '2026-07-19T05:01:00.000Z',
                    'updatedAt': '2026-07-19T05:01:00.000Z',
                    'updatedByDeviceId': null,
                  },
              ],
              'nextCursor': 'cursor-2',
              'hasMore': false,
              'resetRequired': false,
            },
          }),
        );
      } else {
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'records': <Object?>[],
              'nextSnapshotCursor': null,
              'syncCursor': null,
              'hasMore': false,
            },
          }),
        );
      }
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final invalidResponse = throwsA(
      isA<CloudSyncException>()
          .having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.invalidResponse,
          )
          .having((error) => error.retryable, 'retryable', isFalse),
    );
    for (final request in <Future<Object?> Function()>[
      () => client.pullChanges(),
      () => client.pullChanges(limit: 1),
      () => client.pullSnapshot(),
    ]) {
      await expectLater(request(), invalidResponse);
    }
  });

  test('v3 协议版本错误保留服务端错误码与请求标识', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges();
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    request.response
      ..statusCode = 426
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{
            'code': 'SYNC_PROTOCOL_VERSION_UNSUPPORTED',
            'message': 'unsupported protocol',
            'retryable': false,
          },
          'requestId': 'request-1',
        }),
      );
    await request.response.close();

    await expectLater(
      pullFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having((error) => error.statusCode, 'statusCode', 426)
            .having(
              (error) => error.serverCode,
              'serverCode',
              'SYNC_PROTOCOL_VERSION_UNSUPPORTED',
            )
            .having((error) => error.requestId, 'requestId', 'request-1')
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });
}
