import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';

void main() {
  test('同步传输始终携带独立协议版本', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );

    final pushFuture = client.push(<CloudSyncOutboxMutation>[
      CloudSyncOutboxMutation.create(
        mutationId: 'mutation-1',
        entityType: CloudSyncEntityType.conversation,
        entityId: 'conversation-1',
        schemaVersion: 2,
        payload: <String, Object?>{
          'title': '会话',
          'createdAt': '2026-07-16T08:00:00.000Z',
          'updatedAt': '2026-07-16T08:00:00.000Z',
          'isPinned': false,
          'assistantId': null,
          'mcpServerIds': <String>[],
          'truncateIndex': -1,
          'summary': null,
          'lastSummarizedMessageCount': 0,
          'chatSuggestions': <String>[],
        },
      ),
    ]);

    final request = await requestFuture;
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '2');
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'mutationId': 'mutation-1',
              'status': 'applied',
              'revision': 1,
              'changeSeq': 1,
            },
          ],
        },
      }),
    );
    await request.response.close();

    final results = await pushFuture;
    expect(results.single.status, CloudSyncMutationStatus.applied);

    client.close(force: true);
    await server.close(force: true);
  });

  test('附件传输全部携带独立协议版本', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final client = CloudSyncClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );

    Future<void> expectProtocolHeader(
      String path,
      Future<void> Function() send,
    ) async {
      final operation = send();
      expect(await requests.moveNext(), isTrue);
      final request = requests.current;
      expect(request.uri.path, path);
      expect(request.headers.value('x-kelivo-sync-protocol-version'), '2');
      await request.drain<void>();
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'code': 'unauthorized',
              'message': 'unauthorized',
            },
          }),
        );
      await request.response.close();
      await expectLater(operation, throwsA(isA<CloudSyncException>()));
    }

    await expectProtocolHeader('/api/attachment/upload/prepare', () async {
      await client.prepareAttachmentUpload(
        sha256: 'sha256',
        md5Base64: 'md5',
        sizeBytes: 1,
      );
    });
    await expectProtocolHeader('/api/attachment/upload/complete', () async {
      await client.completeAttachmentUpload(
        attachmentId: 'attachment-1',
        blobId: 'blob-1',
        entityType: 'message',
        entityId: 'message-1',
        fileName: 'image.png',
        mimeType: 'image/png',
        etag: 'etag',
      );
    });
    await expectProtocolHeader('/api/attachment/info/list', () async {
      await client.listAttachmentInfo(
        entityType: 'message',
        entityId: 'message-1',
      );
    });
    await expectProtocolHeader('/api/attachment/download-url/get', () async {
      await client.getAttachmentDownloadUrl('attachment-1');
    });
    await expectProtocolHeader('/api/attachment/info/delete', () async {
      await client.deleteAttachmentInfo('attachment-1');
    });

    await requests.cancel();
    client.close(force: true);
    await server.close(force: true);
  });

  test('字段冲突结果保留冲突标识和冲突路径', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );

    final pushFuture = client.push(<CloudSyncOutboxMutation>[
      CloudSyncOutboxMutation.update(
        mutationId: 'mutation-2',
        entityType: CloudSyncEntityType.conversation,
        entityId: 'conversation-1',
        baseRevision: 2,
        patch: <CloudSyncPatch>[CloudSyncPatch.replace('/title', '本地标题')],
      ),
    ]);

    final request = await requestFuture;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'mutationId': 'mutation-2',
              'status': 'conflict',
              'currentRevision': 3,
              'reason': 'field-conflict',
              'conflictId': 'conflict-1',
              'conflictingPaths': <String>['/title'],
              'changeSeq': 7,
            },
          ],
        },
      }),
    );
    await request.response.close();

    final result = (await pushFuture).single;
    expect(result.status, CloudSyncMutationStatus.conflict);
    expect(result.reason, 'field-conflict');
    expect(result.conflictId, 'conflict-1');
    expect(result.conflictingPaths, <String>['/title']);
    expect(result.changeSeq, 7);

    client.close(force: true);
    await server.close(force: true);
  });

  test('父级删除冲突原因能够传回协调器', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );

    final pushFuture = client.push(<CloudSyncOutboxMutation>[
      CloudSyncOutboxMutation.delete(
        mutationId: 'mutation-parent',
        entityType: CloudSyncEntityType.turn,
        entityId: 'turn-1',
        baseRevision: 1,
      ),
    ]);

    final request = await requestFuture;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'mutationId': 'mutation-parent',
              'status': 'conflict',
              'currentRevision': 1,
              'reason': 'parent-deleted',
            },
          ],
        },
      }),
    );
    await request.response.close();

    final result = (await pushFuture).single;
    expect(result.status, CloudSyncMutationStatus.conflict);
    expect(result.reason, 'parent-deleted');

    client.close(force: true);
    await server.close(force: true);
  });

  test('字段冲突可以列出并标记为已解决', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final client = CloudSyncClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
    );

    final listFuture = client.listConflicts(limit: 20);
    expect(await requests.moveNext(), isTrue);
    final listRequest = requests.current;
    expect(listRequest.uri.path, '/api/sync/conflict/list');
    expect(listRequest.headers.value('x-kelivo-sync-protocol-version'), '2');
    expect(
      jsonDecode(await utf8.decoder.bind(listRequest).join()),
      <String, Object?>{'state': 'open', 'limit': 20},
    );
    listRequest.response.headers.contentType = ContentType.json;
    listRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'conflicts': <Object?>[
            _conflictJson(state: 'open', resolvedAt: null),
          ],
        },
      }),
    );
    await listRequest.response.close();

    final conflict = (await listFuture).single;
    expect(conflict.conflictId, 'conflict-1');
    expect(conflict.entityType, CloudSyncEntityType.conversation);
    expect(conflict.baseRevision, 2);
    expect(conflict.state, CloudSyncConflictState.open);
    expect(conflict.fields.single.path, '/title');
    expect(conflict.fields.single.current.exists, isTrue);
    expect(conflict.fields.single.current.value, '云端标题');
    expect(conflict.fields.single.desired.exists, isFalse);

    final resolveFuture = client.resolveConflict('conflict-1');
    expect(await requests.moveNext(), isTrue);
    final resolveRequest = requests.current;
    expect(resolveRequest.uri.path, '/api/sync/conflict/resolve');
    expect(
      jsonDecode(await utf8.decoder.bind(resolveRequest).join()),
      <String, Object?>{'conflictId': 'conflict-1'},
    );
    resolveRequest.response.headers.contentType = ContentType.json;
    resolveRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'conflict': _conflictJson(
            state: 'resolved',
            resolvedAt: '2026-07-16T08:02:00.000Z',
          ),
        },
      }),
    );
    await resolveRequest.response.close();

    final resolved = await resolveFuture;
    expect(resolved.state, CloudSyncConflictState.resolved);
    expect(resolved.resolvedAt, DateTime.utc(2026, 7, 16, 8, 2));

    await requests.cancel();
    client.close(force: true);
    await server.close(force: true);
  });
}

Map<String, Object?> _conflictJson({
  required String state,
  required String? resolvedAt,
}) {
  return <String, Object?>{
    'conflictId': 'conflict-1',
    'mutationId': 'mutation-2',
    'entityType': 'conversation',
    'entityId': 'conversation-1',
    'details': <String, Object?>{
      'baseRevision': 2,
      'fields': <Object?>[
        <String, Object?>{
          'path': '/title',
          'current': <String, Object?>{'exists': true, 'value': '云端标题'},
          'desired': <String, Object?>{'exists': false},
        },
      ],
    },
    'state': state,
    'createdAt': '2026-07-16T08:01:00.000Z',
    'resolvedAt': resolvedAt,
  };
}
