import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/network/dio_http_client.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('旧日志偏好不能让网络正文与凭据形成持久明文副本', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'kelivo_network_plaintext_sentinel_',
    );
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = DioHttpClient();
    addTearDown(() async {
      client.close();
      await server.close(force: true);
      HttpOverrides.global = previousHttpOverrides;
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
      SharedPreferences.resetStatic();
    });
    AppDirectories.bindWorkspaceRoot(workspace, accountWorkspace: false);
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'request_log_enabled_v1': true,
      'log_save_output_v1': true,
    });
    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    final requestHandled = server.first.then((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"reply":"response-plaintext-sentinel"}');
      await request.response.close();
    });
    final request =
        http.Request(
            'POST',
            Uri.parse(
              'http://${server.address.host}:${server.port}/chat'
              '?credential=query-plaintext-sentinel',
            ),
          )
          ..headers['Authorization'] = 'Bearer authorization-plaintext-sentinel'
          ..body = '{"prompt":"request-plaintext-sentinel"}';

    final response = await client.send(request);
    await response.stream.toBytes();
    await requestHandled;
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final persistedText = StringBuffer();
    await for (final entity in workspace.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        persistedText.writeln(await entity.readAsString());
      }
    }
    expect(await Directory(p.join(workspace.path, 'logs')).exists(), isFalse);
    expect(
      persistedText.toString(),
      isNot(
        anyOf(
          contains('query-plaintext-sentinel'),
          contains('authorization-plaintext-sentinel'),
          contains('request-plaintext-sentinel'),
          contains('response-plaintext-sentinel'),
        ),
      ),
    );
  });

  test('网络失败不能把请求凭据与正文写入持久明文副本', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'kelivo_network_failure_plaintext_sentinel_',
    );
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final unavailableServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final unavailablePort = unavailableServer.port;
    await unavailableServer.close(force: true);
    final client = DioHttpClient();
    addTearDown(() async {
      client.close();
      HttpOverrides.global = previousHttpOverrides;
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
      SharedPreferences.resetStatic();
    });
    AppDirectories.bindWorkspaceRoot(workspace, accountWorkspace: false);
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'request_log_enabled_v1': true,
      'log_save_output_v1': true,
    });
    final settings = SettingsProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
    );
    await settings.ready;
    final request =
        http.Request(
            'POST',
            Uri.parse(
              'http://${InternetAddress.loopbackIPv4.address}:'
              '$unavailablePort/chat?credential=failure-query-sentinel',
            ),
          )
          ..headers['Authorization'] = 'Bearer failure-authorization-sentinel'
          ..body = '{"prompt":"failure-request-sentinel"}';

    await expectLater(
      client.send(request),
      throwsA(isA<http.ClientException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final persistedText = StringBuffer();
    await for (final entity in workspace.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        persistedText.writeln(await entity.readAsString());
      }
    }
    expect(await Directory(p.join(workspace.path, 'logs')).exists(), isFalse);
    expect(
      persistedText.toString(),
      isNot(
        anyOf(
          contains('failure-query-sentinel'),
          contains('failure-authorization-sentinel'),
          contains('failure-request-sentinel'),
        ),
      ),
    );
  });
}
