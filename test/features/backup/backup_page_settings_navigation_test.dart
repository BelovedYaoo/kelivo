import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/desktop/setting/backup_pane.dart';
import 'package:Kelivo/features/backup/pages/backup_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

Widget _buildHarness({required Widget home}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        ),
      ),
      ChangeNotifierProvider<McpProvider>(
        create: (_) => McpProvider(
          syncWriteExecutor: const UntrackedSyncWriteExecutor.forTests(),
        ),
      ),
      ChangeNotifierProvider<ChatService>(
        create: (_) => ChatService(const UntrackedSyncWriteExecutor.forTests()),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void _expectLocalOnlyBackupUi() {
  expect(find.text('Local Backup'), findsOneWidget);
  expect(find.text('Export to File'), findsOneWidget);
  expect(find.text('Import Backup File'), findsOneWidget);
  expect(find.text('WebDAV Backup'), findsNothing);
  expect(find.text('WebDAV Server Settings'), findsNothing);
  expect(find.text('S3 Backup'), findsNothing);
  expect(find.text('S3 Settings'), findsNothing);
  expect(find.text('Backup Reminder'), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  testWidgets('移动端仅提供用户主动选择目标的本地备份', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildHarness(home: const BackupPage()));
    await tester.pumpAndSettle();

    _expectLocalOnlyBackupUi();
  });

  testWidgets('桌面端仅提供用户主动选择目标的本地备份', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(home: const Scaffold(body: DesktopBackupPane())),
    );
    await tester.pumpAndSettle();

    _expectLocalOnlyBackupUi();
  });
}
