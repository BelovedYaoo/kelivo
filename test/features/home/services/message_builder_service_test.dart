import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatService extends ChatService {
  _FakeChatService(
    this._toolEventsByMessageId, {
    this.persistedMessages = const [],
  }) : super(const UntrackedSyncWriteExecutor.forTests());

  final Map<String, List<Map<String, dynamic>>> _toolEventsByMessageId;
  final List<ChatMessage> persistedMessages;

  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) {
    return List<Map<String, dynamic>>.of(
      _toolEventsByMessageId[assistantMessageId] ?? const [],
    );
  }

  @override
  List<ChatMessage> getMessages(String conversationId) {
    return persistedMessages
        .where((message) => message.conversationId == conversationId)
        .toList();
  }
}

ChatMessage _message({
  required String id,
  required String role,
  required String content,
  String? reasoningText,
  List<ChatMessageAttachment> attachments = const [],
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    attachments: attachments,
    conversationId: 'conversation-1',
    reasoningText: reasoningText,
  );
}

ChatMessageAttachment _attachment({
  required String assetId,
  required String path,
  required String kind,
  String? displayName,
  String? mediaType,
}) {
  return ChatMessageAttachment(
    assetId: assetId,
    path: path,
    contentHash:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    byteSize: 1,
    kind: kind,
    displayName: displayName,
    mediaType: mediaType,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MessageBuilderService.parseInputFromRaw', () {
    test('只解析本次请求生成的结构化附件标记', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(
            id: 'u1',
            role: 'user',
            content: 'media',
            attachments: [
              _attachment(
                assetId: 'clip',
                path: 'C:/tmp/clip.mp4',
                kind: 'file',
                displayName: 'clip.mp4',
                mediaType: 'video/mp4',
              ),
              _attachment(
                assetId: 'audio',
                path: 'C:/tmp/audio.wav',
                kind: 'file',
                displayName: 'audio.wav',
                mediaType: 'audio/wav',
              ),
            ],
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );
      final input = service.parseInputFromRaw(
        apiMessages.single['content'] as String,
      );

      expect(input.text, 'media');
      expect(input.imagePaths, ['C:/tmp/clip.mp4', 'C:/tmp/audio.wav']);
      expect(input.documents.map((document) => document.fileName), [
        'clip.mp4',
        'audio.wav',
      ]);
    });

    test('本地旧标记按普通文本保留，远程图片标记继续解析', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );

      final input = service.parseInputFromRaw(
        'local\n'
        '[image:C:/tmp/photo.png]\n'
        '[file:C:/tmp/clip.mp4|clip.mp4|video/mp4]\n'
        '[image:https://example.com/remote.png]\n'
        '[image:data:image/png;base64,AA==]',
      );

      expect(input.text, contains('[image:C:/tmp/photo.png]'));
      expect(input.text, contains('[file:C:/tmp/clip.mp4|clip.mp4|video/mp4]'));
      expect(input.imagePaths, [
        'https://example.com/remote.png',
        'data:image/png;base64,AA==',
      ]);
      expect(input.documents, isEmpty);
    });
  });

  group('MessageBuilderService.buildApiMessages', () {
    test('结构化附件保持顺序且仅附件消息不会被丢弃', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final attachments = [
        _attachment(assetId: 'image-a', path: 'C:/tmp/a.png', kind: 'image'),
        _attachment(
          assetId: 'file-b',
          path: 'C:/tmp/b.txt',
          kind: 'file',
          displayName: 'b.txt',
          mediaType: 'text/plain',
        ),
        _attachment(assetId: 'image-c', path: 'C:/tmp/c.png', kind: 'image'),
      ];

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(
            id: 'u1',
            role: 'user',
            content: '',
            attachments: attachments,
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );

      expect(apiMessages, hasLength(1));
      final content = apiMessages.single['content'] as String;
      final kinds = RegExp(r'\[kelivo-attachment:[^:]+:([A-Za-z0-9_-]+)\]')
          .allMatches(content)
          .map((match) {
            final encoded = match.group(1)!;
            final paddedLength = ((encoded.length + 3) ~/ 4) * 4;
            final payload = utf8.decode(
              base64Url.decode(encoded.padRight(paddedLength, '=')),
            );
            return (jsonDecode(payload) as Map<String, dynamic>)['kind'];
          });
      expect(kinds, ['image', 'file', 'image']);
    });

    test('结构化附件进入 API 内容且不会遗留内部标记', () async {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final tempDirectory = await Directory.systemTemp.createTemp(
        'kelivo-attachment-read-',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final document = File(
        '${tempDirectory.path}${Platform.pathSeparator}说明.txt',
      );
      await document.writeAsString('结构化文件正文');
      final imagePath = '${tempDirectory.path}${Platform.pathSeparator}图片.png';
      final apiMessages = service.buildApiMessages(
        messages: [
          _message(
            id: 'u1',
            role: 'user',
            content:
                '请处理附件\n[image:C:/legacy.png]\n[image:https://example.com/remote.png]',
            attachments: [
              _attachment(assetId: 'image', path: imagePath, kind: 'image'),
              _attachment(
                assetId: 'document',
                path: document.path,
                kind: 'file',
                displayName: '说明.txt',
                mediaType: 'text/plain',
              ),
            ],
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );

      final imagePaths = await service.processUserMessagesForApi(
        apiMessages,
        SettingsProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        ),
        const Assistant(id: 'assistant-1', name: 'test'),
      );

      final content = apiMessages.single['content'] as String;
      expect(imagePaths, ['https://example.com/remote.png', imagePath]);
      expect(content, contains('[image:C:/legacy.png]'));
      expect(content, contains('[image:https://example.com/remote.png]'));
      expect(content, contains('[image:$imagePath]'));
      expect(content, contains('说明.txt'));
      expect(content, contains('结构化文件正文'));
      expect(content, isNot(contains('[kelivo-attachment:')));
      expect(
        apiMessages.single.keys.toSet().difference(const {
          'role',
          'content',
          MessageBuilderService.internalMediaPathsKey,
        }),
        isEmpty,
      );
    });

    test('有工具调用时会把 reasoning_content 回填到 assistant tool 消息', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'get_weather',
              'arguments': {'location': 'Hangzhou', 'date': '2026-04-25'},
              'content': 'Cloudy 7~13°C',
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '杭州明天天气怎么样？'),
          _message(
            id: 'a1',
            role: 'assistant',
            content: '明天多云，7 到 13 度。',
            reasoningText: '先判断日期，再查询天气。',
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final assistantToolMessage = apiMessages.firstWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] is List,
      );
      final finalAssistantMessage = apiMessages.lastWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] == null,
      );

      expect(assistantToolMessage['content'], '\n\n');
      expect(assistantToolMessage['reasoning_content'], '先判断日期，再查询天气。');
      expect(finalAssistantMessage['reasoning_content'], '先判断日期，再查询天气。');
    });

    test('reasoningText 为空时不会伪造 reasoning_content', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'get_date',
              'arguments': <String, dynamic>{},
              'content': '2026-04-24',
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '今天几号？'),
          _message(
            id: 'a1',
            role: 'assistant',
            content: '今天是 2026-04-24。',
            reasoningText: '',
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final assistantToolMessage = apiMessages.firstWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] is List,
      );
      final finalAssistantMessage = apiMessages.lastWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] == null,
      );

      expect(assistantToolMessage.containsKey('reasoning_content'), isFalse);
      expect(finalAssistantMessage.containsKey('reasoning_content'), isFalse);
    });

    test('恢复工具回答续写时只发送 tool call 和 tool result', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'ask_user_input_v0',
              'arguments': {
                'questions': [
                  {
                    'id': 'scope',
                    'question': '选哪个范围？',
                    'type': 'single',
                    'options': ['最小', '完整'],
                  },
                ],
              },
              'content':
                  '{"type":"ask_user_answer","answers":{"scope":{"type":"single","value":"完整","custom":false,"skipped":false}}}',
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '开始吧'),
          _message(id: 'a1', role: 'assistant', content: ''),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      expect(
        apiMessages.where(
          (message) =>
              message['role'] == 'assistant' && message['tool_calls'] == null,
        ),
        isEmpty,
      );
      expect(
        apiMessages.where(
          (message) =>
              message['role'] == 'assistant' && message['tool_calls'] is List,
        ),
        hasLength(1),
      );
      expect(
        apiMessages.where((message) => message['role'] == 'tool'),
        hasLength(1),
      );
    });

    test('传入消息缺少 reasoningText 时会从已持久化消息兜底回填', () {
      final persistedAssistant = _message(
        id: 'a1',
        role: 'assistant',
        content: '现在是北京时间下午三点。',
        reasoningText: '先调用时间工具，再整理成中文时间。',
      );
      final service = MessageBuilderService(
        chatService: _FakeChatService(
          {
            'a1': [
              {
                'id': 'call_1',
                'name': 'get-current-time',
                'arguments': {'timeZone': 'Asia/Shanghai'},
                'content': 'Friday, 2026-04-24 15:25:41',
              },
            ],
          },
          persistedMessages: [
            _message(id: 'u1', role: 'user', content: '现在几点了'),
            persistedAssistant,
          ],
        ),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '现在几点了'),
          _message(id: 'a1', role: 'assistant', content: '现在是北京时间下午三点。'),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final assistantToolMessage = apiMessages.firstWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] is List,
      );
      final finalAssistantMessage = apiMessages.lastWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] == null,
      );

      expect(assistantToolMessage['reasoning_content'], '先调用时间工具，再整理成中文时间。');
      expect(finalAssistantMessage['reasoning_content'], '先调用时间工具，再整理成中文时间。');
    });

    test('关闭 OpenAI 工具消息重建时不额外注入 assistant tool 消息', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'get_weather',
              'arguments': {'location': 'Hangzhou'},
              'content': 'Cloudy',
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '帮我查天气'),
          _message(
            id: 'a1',
            role: 'assistant',
            content: '明天多云。',
            reasoningText: '先查日期，再查天气。',
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: false,
      );

      expect(
        apiMessages.where((message) => message['tool_calls'] is List),
        isEmpty,
      );
    });

    test('工具历史会保留 provider 元数据供 Claude 和 Gemini 重放', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'lookup',
              'arguments': {'query': 'Kelivo'},
              'content': '{"result":"ok"}',
              'metadata': {
                'anthropic': {
                  'assistant_blocks': [
                    {
                      'type': 'thinking',
                      'thinking': '需要查询资料。',
                      'signature': 'sig-claude',
                    },
                    {
                      'type': 'tool_use',
                      'id': 'call_1',
                      'name': 'lookup',
                      'input': {'query': 'Kelivo'},
                    },
                  ],
                },
                'google': {
                  'part': {
                    'functionCall': {
                      'name': 'lookup',
                      'args': {'query': 'Kelivo'},
                    },
                    'thoughtSignature': 'sig-gemini',
                  },
                },
              },
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '查 Kelivo'),
          _message(id: 'a1', role: 'assistant', content: '查到了。'),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final assistantToolMessage = apiMessages.firstWhere(
        (message) => message['tool_calls'] is List,
      );
      final toolMessage = apiMessages.firstWhere(
        (message) => message['role'] == 'tool',
      );
      final toolCall =
          (assistantToolMessage['tool_calls'] as List).single
              as Map<String, dynamic>;

      expect(toolCall['metadata']['anthropic']['assistant_blocks'], isNotEmpty);
      expect(
        toolCall['metadata']['google']['part']['thoughtSignature'],
        'sig-gemini',
      );
      expect(
        toolMessage['metadata']['google']['part']['thoughtSignature'],
        'sig-gemini',
      );
    });

    test('未完成的工具占位事件不会被重建为 API tool call', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'create_memory',
              'arguments': {'content': 'test'},
              'content': null,
              'metadata': {
                'anthropic': {
                  'assistant_blocks': [
                    {
                      'type': 'tool_use',
                      'id': 'call_1',
                      'name': 'create_memory',
                      'input': {'content': 'test'},
                    },
                  ],
                },
              },
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '记一下'),
          _message(id: 'a1', role: 'assistant', content: '稍后继续。'),
          _message(id: 'u2', role: 'user', content: 'ok'),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      expect(
        apiMessages.where((message) => message['tool_calls'] is List),
        isEmpty,
      );
      expect(
        apiMessages.where((message) => message['role'] == 'tool'),
        isEmpty,
      );
      expect(apiMessages.map((message) => message['content']).toList(), [
        '记一下',
        '稍后继续。',
        'ok',
      ]);
    });

    test('无限制上下文不会裁掉一千条以上的消息', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = <Map<String, dynamic>>[
        for (var index = 0; index < 1507; index++)
          {
            'role': index.isEven ? 'user' : 'assistant',
            'content': 'message-$index',
          },
      ];

      service.applyContextLimit(
        apiMessages,
        const Assistant(
          id: 'assistant-1',
          name: 'test',
          limitContextMessages: false,
        ),
      );

      expect(apiMessages, hasLength(1507));
      expect(apiMessages.first['content'], 'message-0');
      expect(apiMessages.last['content'], 'message-1506');
    });

    test('上下文裁剪不会保留缺少 tool result 的 assistant tool call', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'before'},
        {
          'role': 'assistant',
          'content': '\n\n',
          'tool_calls': [
            {
              'id': 'call_1',
              'type': 'function',
              'function': {'name': 'create_memory', 'arguments': '{}'},
            },
          ],
        },
        {
          'role': 'tool',
          'tool_call_id': 'call_1',
          'name': 'create_memory',
          'content': 'ok',
        },
        {'role': 'assistant', 'content': 'done'},
        {'role': 'user', 'content': 'next'},
      ];

      service.applyContextLimit(
        apiMessages,
        const Assistant(id: 'assistant-1', name: 'test', contextMessageSize: 3),
      );

      expect(
        apiMessages.where((message) => message['tool_calls'] is List),
        isEmpty,
      );
      expect(
        apiMessages.where((message) => message['role'] == 'tool'),
        isEmpty,
      );
      expect(apiMessages.map((message) => message['content']).toList(), [
        'done',
        'next',
      ]);
    });

    test('上下文裁剪会保留完整的 assistant tool call 与 tool result', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'before'},
        {
          'role': 'assistant',
          'content': '\n\n',
          'tool_calls': [
            {
              'id': 'call_1',
              'type': 'function',
              'function': {'name': 'create_memory', 'arguments': '{}'},
            },
          ],
        },
        {
          'role': 'tool',
          'tool_call_id': 'call_1',
          'name': 'create_memory',
          'content': 'ok',
        },
        {'role': 'assistant', 'content': 'done'},
        {'role': 'user', 'content': 'next'},
      ];

      service.applyContextLimit(
        apiMessages,
        const Assistant(id: 'assistant-1', name: 'test', contextMessageSize: 4),
      );

      expect(
        apiMessages.where((message) => message['tool_calls'] is List),
        hasLength(1),
      );
      expect(
        apiMessages.where((message) => message['role'] == 'tool'),
        hasLength(1),
      );
      expect(apiMessages.map((message) => message['role']).toList(), [
        'assistant',
        'tool',
        'assistant',
        'user',
      ]);
    });
  });
}
