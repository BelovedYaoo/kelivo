import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('结构化附件按顺序显示在文本气泡上方', (tester) async {
    const messageId = 'user-with-attachments';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(
              syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => UserProvider(
              syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              showUserAvatar: false,
              message: ChatMessage(
                id: messageId,
                role: 'user',
                content: '请看这个\n[image:missing-legacy-image.png]',
                attachments: [
                  ChatMessageAttachment(
                    assetId: 'spec',
                    path: '/tmp/spec.pdf',
                    contentHash:
                        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                    byteSize: 1,
                    kind: 'file',
                    displayName: 'spec.pdf',
                    mediaType: 'application/pdf',
                  ),
                  ChatMessageAttachment(
                    assetId: 'image',
                    path: 'missing-structured-image.png',
                    contentHash:
                        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                    byteSize: 1,
                    kind: 'image',
                  ),
                ],
                conversationId: 'conversation-user-attachments',
              ),
            ),
          ),
        ),
      ),
    );

    final bubbleFinder = find.byKey(
      const ValueKey('user-message-text-bubble:$messageId'),
    );
    final attachmentsFinder = find.byKey(
      const ValueKey('user-message-attachments:$messageId'),
    );
    final listFinder = find.byKey(
      const ValueKey('user-message-attachment-list:$messageId'),
    );

    expect(bubbleFinder, findsOneWidget);
    expect(attachmentsFinder, findsOneWidget);
    expect(listFinder, findsOneWidget);
    expect(
      find.descendant(
        of: bubbleFinder,
        matching: find.text('请看这个\n[image:missing-legacy-image.png]'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bubbleFinder, matching: find.text('spec.pdf')),
      findsNothing,
    );
    expect(
      find.descendant(of: bubbleFinder, matching: find.byType(Image)),
      findsNothing,
    );
    expect(
      find.descendant(of: attachmentsFinder, matching: find.text('spec.pdf')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: attachmentsFinder, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: attachmentsFinder, matching: find.byType(InkWell)),
      findsNothing,
    );
    final attachmentList = tester.widget<Wrap>(listFinder);
    expect(attachmentList.children.map((child) => child.key), const [
      ValueKey('user-message-attachment:$messageId:0'),
      ValueKey('user-message-attachment:$messageId:1'),
    ]);

    final attachmentsRect = tester.getRect(attachmentsFinder);
    final bubbleRect = tester.getRect(bubbleFinder);
    expect(attachmentsRect.bottom, lessThanOrEqualTo(bubbleRect.top));
  });

  testWidgets('远程图片标记继续显示且本地旧标记不会生成附件', (tester) async {
    const messageId = 'remote-image-marker';
    const remoteImage =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADElEQVR42mNk+M8AAAICAQB7CYk1AAAAAElFTkSuQmCC';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(
              syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => UserProvider(
              syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              showUserAvatar: false,
              message: ChatMessage(
                id: messageId,
                role: 'user',
                content:
                    '远程图片\n[image:$remoteImage]\n[image:C:/legacy.png]\n[file:C:/legacy.txt|legacy.txt|text/plain]',
                conversationId: 'conversation-remote-image-marker',
              ),
            ),
          ),
        ),
      ),
    );

    final attachmentsFinder = find.byKey(
      const ValueKey('user-message-attachments:$messageId'),
    );
    final attachmentList = tester.widget<Wrap>(
      find.byKey(const ValueKey('user-message-attachment-list:$messageId')),
    );
    expect(attachmentList.children, hasLength(1));
    expect(
      find.descendant(of: attachmentsFinder, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(find.textContaining('[image:C:/legacy.png]'), findsOneWidget);
    expect(
      find.textContaining('[file:C:/legacy.txt|legacy.txt|text/plain]'),
      findsOneWidget,
    );
    expect(find.textContaining(remoteImage), findsNothing);
  });
}
