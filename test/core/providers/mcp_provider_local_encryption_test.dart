import 'dart:convert';

import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/secure_core_test_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SecureCoreTestStoreScope testStoreScope;

  setUp(() {
    testStoreScope = SecureCoreTestStoreScope.open();
  });

  tearDown(() {
    testStoreScope.close();
  });

  test('本地 MCP 服务器以安全槽密封存储且可回读', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final provider = McpProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      secureCore: const KelivoSecureCore(),
    );
    await provider.ready;
    await provider.addServer(
      enabled: true,
      name: 'local-tool',
      transport: McpTransportType.stdio,
      command: 'npx',
      args: const <String>['-y', 'tool'],
      env: const <String, String>{'API_KEY': 'super-secret'},
    );

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('mcp_servers_v1')!;
    expect(stored, startsWith('kelivo-mcp-v1:'));
    expect(stored, isNot(contains('super-secret')));

    final reopened = McpProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      secureCore: const KelivoSecureCore(),
    );
    await reopened.ready;
    final server = reopened.servers.firstWhere(
      (server) => server.name == 'local-tool',
    );
    expect(server.env['API_KEY'], 'super-secret');
  });

  test('旧明文 MCP 数据加载后迁移为密封存储', () async {
    final plaintext = jsonEncode(<Map<String, Object?>>[
      <String, Object?>{
        'id': 'legacy-local',
        'name': 'legacy',
        'enabled': true,
        'transport': 'stdio',
        'command': 'npx',
        'args': <String>[],
        'env': <String, String>{'TOKEN': 'legacy-secret'},
        'workingDirectory': null,
      },
    ]);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mcp_servers_v1': plaintext,
    });
    final provider = McpProvider(
      syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
      secureCore: const KelivoSecureCore(),
    );
    await provider.ready;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mcp_servers_v1'), startsWith('kelivo-mcp-v1:'));
  });
}
