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
}
