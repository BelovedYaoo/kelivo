import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/assistant_memory.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/utils/app_directories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MCP 仅返回 URL 的图片时保留远程图片标记', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mcp_servers_v1': jsonEncode(<Map<String, dynamic>>[
        McpServerConfig(
          id: 'kelivo_fetch',
          enabled: false,
          name: '@kelivo/fetch',
          transport: McpTransportType.inmemory,
        ).toJson(),
      ]),
    });
    final temp = await Directory.systemTemp.createTemp('kelivo_mcp_url_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    AppDirectories.bindWorkspaceRoot(
      temp,
      installationRoot: temp,
      accountWorkspace: false,
    );
    final provider = _ImageMcpProvider(
      const mcp.CallToolResult(<mcp.Content>[
        mcp.ImageContent(
          url: 'https://example.com/tool.png',
          mimeType: 'image/png',
        ),
      ]),
    );
    await provider.ready;
    final chat = _McpChatService();
    addTearDown(provider.dispose);
    addTearDown(chat.dispose);

    final result = await McpToolService().callToolTextForConversation(
      provider,
      chat,
      conversationId: 'conversation-1',
      toolName: 'render-image',
    );

    expect(result, '[image:https://example.com/tool.png]');
  });

  group('ToolHandlerService memory tools', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('edit_memory returns updated content when id exists', (
      tester,
    ) async {
      const assistant = Assistant(
        id: 'assistant-a',
        name: 'Assistant',
        enableMemory: true,
      );

      late String result;
      await tester.pumpWidget(
        _ToolHandlerTestScope(
          child: Builder(
            builder: (context) {
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final memoryProvider = context.read<MemoryProvider>();
      final memory = await memoryProvider.add(
        assistantId: assistant.id,
        content: 'old memory',
      );
      final handler = ToolHandlerService(contextProvider: context)
          .buildToolCallHandler(
            SettingsProvider(
              syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
            ),
            assistant,
          )!;

      result = await handler('edit_memory', {
        'id': memory.id,
        'content': 'new memory',
      });

      expect(result, 'new memory');
    });

    testWidgets('edit_memory returns tool error when id does not exist', (
      tester,
    ) async {
      const assistant = Assistant(
        id: 'assistant-a',
        name: 'Assistant',
        enableMemory: true,
      );

      await tester.pumpWidget(
        _ToolHandlerTestScope(
          child: Builder(
            builder: (context) {
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final handler = ToolHandlerService(contextProvider: context)
          .buildToolCallHandler(
            SettingsProvider(
              syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
            ),
            assistant,
          )!;

      final result = await handler('edit_memory', {
        'id': 410,
        'content': 'new memory',
      });

      final payload = jsonDecode(result) as Map<String, dynamic>;
      expect(payload['type'], 'tool_error');
      expect(payload['error'], 'memory_not_found');
      expect(payload['tool'], 'edit_memory');
      expect(payload['message'], contains('410'));
    });

    testWidgets('edit_memory returns tool error when update throws', (
      tester,
    ) async {
      const assistant = Assistant(
        id: 'assistant-a',
        name: 'Assistant',
        enableMemory: true,
      );

      await tester.pumpWidget(
        _ToolHandlerTestScope(
          memoryProvider: _ThrowingMemoryProvider(),
          child: Builder(
            builder: (context) {
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final handler = ToolHandlerService(contextProvider: context)
          .buildToolCallHandler(
            SettingsProvider(
              syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
            ),
            assistant,
          )!;

      final result = await handler('edit_memory', {
        'id': 410,
        'content': 'new memory',
      });

      final payload = jsonDecode(result) as Map<String, dynamic>;
      expect(payload['type'], 'tool_error');
      expect(payload['error'], 'memory_execution_error');
      expect(payload['tool'], 'edit_memory');
      expect(payload['message'], contains('storage offline'));
    });
  });
}

final class _ImageMcpProvider extends McpProvider {
  _ImageMcpProvider(this.result)
    : super(syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests());

  final mcp.CallToolResult result;

  @override
  List<McpServerConfig> get connectedServers => <McpServerConfig>[
    McpServerConfig(
      id: 'server-1',
      enabled: true,
      name: 'Test server',
      transport: McpTransportType.http,
      tools: <McpToolConfig>[
        McpToolConfig(enabled: true, name: 'render-image'),
      ],
    ),
  ];

  @override
  Future<mcp.CallToolResult?> callTool(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  ) async => result;
}

final class _McpChatService extends ChatService {
  _McpChatService() : super(const UntrackedSyncWriteExecutor.forTests());

  @override
  List<String> getConversationMcpServers(String conversationId) => <String>[
    'server-1',
  ];
}

class _ToolHandlerTestScope extends StatelessWidget {
  const _ToolHandlerTestScope({required this.child, this.memoryProvider});

  final Widget child;
  final MemoryProvider? memoryProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AssistantProvider>(
          create: (_) => AssistantProvider(
            syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
          ),
        ),
        ChangeNotifierProvider<McpProvider>(
          create: (_) => McpProvider(
            syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
          ),
        ),
        ChangeNotifierProvider<McpToolService>(create: (_) => McpToolService()),
        ChangeNotifierProvider<MemoryProvider>(
          create: (_) =>
              memoryProvider ??
              MemoryProvider(
                syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
              ),
        ),
      ],
      child: child,
    );
  }
}

class _ThrowingMemoryProvider extends MemoryProvider {
  _ThrowingMemoryProvider()
    : super(syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests());

  @override
  Future<AssistantMemory?> update({required int id, required String content}) {
    throw StateError('storage offline');
  }
}
