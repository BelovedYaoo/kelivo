import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant_memory.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/memory_store.dart';

void main() {
  group('Conversation chat suggestions compatibility', () {
    test('fromJson defaults missing suggestions to empty list', () {
      final conversation = Conversation.fromJson({
        'id': 'conversation-1',
        'title': 'Chat',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 2).toIso8601String(),
        'messageIds': <String>[],
      });

      expect(conversation.chatSuggestions, isEmpty);
    });

    test('toJson includes chat suggestions', () {
      final conversation = Conversation(
        id: 'conversation-2',
        title: 'Chat',
        chatSuggestions: const ['继续', '举例'],
      );

      expect(conversation.toJson()['chatSuggestions'], ['继续', '举例']);
    });
  });

  group('ChatMessage domain', () {
    test('new messages derive stable group and turn ids from generated id', () {
      final message = ChatMessage(
        role: 'user',
        content: 'hello',
        conversationId: 'conversation-1',
      );

      expect(message.groupId, message.id);
      expect(message.turnId, message.id);
      expect(message.generationStatus, ChatMessage.generationStatusCompleted);
    });

    test('explicit turn id wins over group id and generated id', () {
      final message = ChatMessage(
        id: 'message-1',
        role: 'assistant',
        content: '',
        conversationId: 'conversation-1',
        groupId: 'group-1',
        turnId: 'turn-1',
        isStreaming: true,
      );

      expect(message.groupId, 'group-1');
      expect(message.turnId, 'turn-1');
      expect(message.generationStatus, ChatMessage.generationStatusDraft);
    });

    test(
      'persisted json infers status and ids without changing persisted ids',
      () {
        final message = ChatMessage.fromJson({
          'id': 'message-1',
          'role': 'assistant',
          'content': 'partial',
          'attachments': <Object?>[],
          'timestamp': '2026-07-15T00:00:00.000Z',
          'conversationId': 'conversation-1',
          'isStreaming': true,
        });

        expect(message.groupId, 'message-1');
        expect(message.turnId, 'message-1');
        expect(message.generationStatus, ChatMessage.generationStatusDraft);
      },
    );

    test(
      'structured attachments are immutable and survive JSON round trips',
      () {
        final source = <ChatMessageAttachment>[
          ChatMessageAttachment(
            assetId: 'asset-1',
            path: r'D:\workspace\assets\file.txt',
            contentHash: List<String>.filled(64, 'a').join(),
            byteSize: 42,
            kind: 'file',
            displayName: 'file.txt',
            mediaType: 'text/plain',
            attachmentId: 'a0000000-0000-4000-8000-000000000001',
            uploadId: 'b0000000-0000-4000-8000-000000000001',
            chunkKeyEpoch: 5,
            manifestKeyEpoch: 7,
            manifestRevision: 3,
          ),
        ];
        final message = ChatMessage(
          id: 'message-attachment-1',
          role: 'user',
          content: 'file',
          attachments: source,
          conversationId: 'conversation-1',
        );

        source.clear();
        expect(message.attachments, hasLength(1));
        expect(
          () => message.attachments.add(message.attachments.single),
          throwsUnsupportedError,
        );

        final restored = ChatMessage.fromJson(message.toJson());
        final attachment = restored.attachments.single;
        expect(attachment.assetId, 'asset-1');
        expect(attachment.path, r'D:\workspace\assets\file.txt');
        expect(attachment.contentHash, List<String>.filled(64, 'a').join());
        expect(attachment.byteSize, 42);
        expect(attachment.kind, 'file');
        expect(attachment.displayName, 'file.txt');
        expect(attachment.mediaType, 'text/plain');
        expect(attachment.attachmentId, 'a0000000-0000-4000-8000-000000000001');
        expect(attachment.uploadId, 'b0000000-0000-4000-8000-000000000001');
        expect(attachment.chunkKeyEpoch, 5);
        expect(attachment.manifestKeyEpoch, 7);
        expect(attachment.manifestRevision, 3);
        expect(restored.copyWith(content: 'updated').attachments, hasLength(1));
        expect(restored.copyWith(attachments: const []).attachments, isEmpty);
      },
    );

    test('structured attachment JSON and remote identity fail closed', () {
      expect(
        () => ChatMessage.fromJson({
          'id': 'message-1',
          'role': 'user',
          'content': 'plain',
          'timestamp': '2026-07-15T00:00:00.000Z',
          'conversationId': 'conversation-1',
        }),
        throwsFormatException,
      );
      expect(
        () => ChatMessageAttachment(
          assetId: 'asset-1',
          path: r'D:\workspace\assets\file.txt',
          contentHash: List<String>.filled(64, 'a').join(),
          byteSize: 42,
          kind: 'file',
          displayName: 'file.txt',
          mediaType: 'text/plain',
          attachmentId: 'a0000000-0000-4000-8000-000000000001',
        ),
        throwsArgumentError,
      );
      expect(
        () => ChatMessageAttachment.fromJson(<String, Object?>{
          'assetId': 'asset-1',
          'path': r'D:\workspace\assets\file.txt',
          'contentHash': List<String>.filled(64, 'a').join(),
          'byteSize': 42,
          'kind': 'file',
          'displayName': 'file.txt',
          'mediaType': 'text/plain',
          'attachmentId': 'a0000000-0000-4000-8000-000000000001',
          'uploadId': 'b0000000-0000-4000-8000-000000000001',
          'keyEpoch': 7,
        }),
        throwsA(isA<FormatException>()),
      );
      final attachment = ChatMessageAttachment(
        assetId: 'asset-1',
        path: r'D:\workspace\assets\file.txt',
        contentHash: List<String>.filled(64, 'a').join(),
        byteSize: 42,
        kind: 'file',
        displayName: 'file.txt',
        mediaType: 'text/plain',
      );
      expect(
        () => ChatMessage(
          role: 'user',
          content: 'too many files',
          attachments: List<ChatMessageAttachment>.filled(33, attachment),
          conversationId: 'conversation-1',
        ),
        throwsRangeError,
      );
    });

    test('copyWith completes ordinary streams but keeps explicit failures', () {
      final draft = ChatMessage(
        role: 'assistant',
        content: 'partial',
        conversationId: 'conversation-1',
        isStreaming: true,
      );

      final completed = draft.copyWith(isStreaming: false);
      final failed = draft.copyWith(
        isStreaming: false,
        generationStatus: ChatMessage.generationStatusFailed,
      );
      final interrupted = draft.copyWith(
        isStreaming: false,
        generationStatus: ChatMessage.generationStatusInterrupted,
      );

      expect(completed.generationStatus, ChatMessage.generationStatusCompleted);
      expect(failed.generationStatus, ChatMessage.generationStatusFailed);
      expect(
        interrupted.generationStatus,
        ChatMessage.generationStatusInterrupted,
      );
      expect(ChatMessage.fromJson(failed.toJson()).turnId, failed.turnId);
    });
  });

  group('AssistantMemory sync compatibility', () {
    test('legacy records derive the same deterministic sync id', () {
      final json = <String, dynamic>{
        'id': 7,
        'assistantId': 'assistant-1',
        'content': 'remember this',
      };

      final first = AssistantMemory.fromJson(json);
      final second = AssistantMemory.fromJson(json);
      final invalidStoredId = AssistantMemory.fromJson(<String, dynamic>{
        ...json,
        'syncId': 7,
      });

      expect(first.syncId, second.syncId);
      expect(invalidStoredId.syncId, first.syncId);
      expect(first.copyWith(content: 'updated').syncId, first.syncId);
      expect(first.toJson()['syncId'], first.syncId);
    });

    test('new records receive distinct uuid sync ids', () {
      final first = AssistantMemory(
        id: 1,
        assistantId: 'assistant-1',
        content: 'first',
      );
      final second = AssistantMemory(
        id: 2,
        assistantId: 'assistant-1',
        content: 'second',
      );

      expect(first.syncId, isNotEmpty);
      expect(second.syncId, isNot(first.syncId));
    });

    test(
      'memory store persists deterministic ids while migrating old json',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'assistant_memories_v1': jsonEncode(<Map<String, Object>>[
            <String, Object>{
              'id': 7,
              'assistantId': 'assistant-1',
              'content': 'remember this',
            },
          ]),
        });

        final memories = await MemoryStore.getAll();
        final preferences = await SharedPreferences.getInstance();
        final persisted =
            jsonDecode(preferences.getString('assistant_memories_v1')!)
                as List<dynamic>;
        final persistedMemory = (persisted.single as Map)
            .cast<String, dynamic>();

        expect(memories.single.syncId, isNotEmpty);
        expect(persistedMemory['syncId'], memories.single.syncId);
      },
    );
  });
}
