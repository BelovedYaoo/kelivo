import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('persisted user message text', () {
    test('仅保留处理后的用户文本，不写入附件路径', () {
      final content = MessageGenerationService.buildPersistedUserMessageText(
        const ChatInputData(
          text: '  edited prompt  ',
          imagePaths: ['C:/tmp/image.png'],
          documents: [
            DocumentAttachment(
              path: 'C:/tmp/spec.pdf',
              fileName: 'spec.pdf',
              mime: 'application/pdf',
            ),
          ],
        ),
        assistant: null,
      );

      expect(content, 'edited prompt');
    });

    test('纯附件输入不会伪造占位正文', () {
      final content = MessageGenerationService.buildPersistedUserMessageText(
        const ChatInputData(text: '', imagePaths: ['C:/tmp/image.png']),
        assistant: null,
      );

      expect(content, isEmpty);
    });
  });
}
