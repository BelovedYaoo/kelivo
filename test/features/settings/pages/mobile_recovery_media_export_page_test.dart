import 'dart:typed_data';

import 'package:Kelivo/features/settings/pages/mobile_recovery_media_export_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

void main() {
  testWidgets('固定 644B 恢复介质可完整渲染二维码并经用户确认', (tester) async {
    final harnessKey = GlobalKey<_ExportHarnessState>();
    await tester.pumpWidget(
      _testApp(
        _ExportHarness(
          key: harnessKey,
          encryptedMedia: _encryptedMedia(),
          fileSaver: (_) async => true,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-export-page')));
    await tester.pumpAndSettle();

    final encoded = QrImage(
      QrCode.fromUint8List(
        data: _encryptedMedia(),
        errorCorrectLevel: QrErrorCorrectLevel.L,
      ),
    );
    expect(encoded.moduleCount, lessThanOrEqualTo(177));
    expect(encoded.moduleCount, greaterThan(0));
    expect(find.byType(PrettyQrView), findsOneWidget);

    final acknowledgement = find.byKey(
      const ValueKey<String>('mobile-recovery-export-acknowledgement'),
    );
    await tester.scrollUntilVisible(acknowledgement, 240);
    await tester.tap(acknowledgement);
    await tester.pump();
    final confirm = find.byKey(
      const ValueKey<String>('mobile-recovery-export-confirm'),
    );
    await tester.scrollUntilVisible(confirm, 120);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(
      harnessKey.currentState?.result,
      MobileRecoveryMediaExportResult.confirmed,
    );
  });

  testWidgets('用户取消恢复介质导出时返回未确认', (tester) async {
    final harnessKey = GlobalKey<_ExportHarnessState>();
    await tester.pumpWidget(
      _testApp(
        _ExportHarness(
          key: harnessKey,
          encryptedMedia: _encryptedMedia(),
          fileSaver: (_) async => true,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-export-page')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('mobile-recovery-export-cancel')),
    );
    await tester.pumpAndSettle();

    expect(
      harnessKey.currentState?.result,
      MobileRecoveryMediaExportResult.cancelled,
    );
  });

  testWidgets('恢复文件保存失败时返回失败且不能确认注册', (tester) async {
    final harnessKey = GlobalKey<_ExportHarnessState>();
    await tester.pumpWidget(
      _testApp(
        _ExportHarness(
          key: harnessKey,
          encryptedMedia: _encryptedMedia(),
          fileSaver: (_) async => false,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-export-page')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('mobile-recovery-export-save-file')),
    );
    await tester.pumpAndSettle();

    expect(
      harnessKey.currentState?.result,
      MobileRecoveryMediaExportResult.fileSaveFailed,
    );
  });

  testWidgets('恢复文件保存成功后仍需用户明确确认', (tester) async {
    final harnessKey = GlobalKey<_ExportHarnessState>();
    Uint8List? savedMedia;
    await tester.pumpWidget(
      _testApp(
        _ExportHarness(
          key: harnessKey,
          encryptedMedia: _encryptedMedia(),
          fileSaver: (media) async {
            savedMedia = Uint8List.fromList(media);
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-export-page')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('mobile-recovery-export-save-file')),
    );
    await tester.pump();

    expect(savedMedia, orderedEquals(_encryptedMedia()));
    expect(harnessKey.currentState?.result, isNull);
    expect(
      find.byKey(const ValueKey<String>('mobile-recovery-export-file-saved')),
      findsOneWidget,
    );

    final acknowledgement = find.byKey(
      const ValueKey<String>('mobile-recovery-export-acknowledgement'),
    );
    await tester.scrollUntilVisible(acknowledgement, 240);
    await tester.tap(acknowledgement);
    await tester.pump();
    final confirm = find.byKey(
      const ValueKey<String>('mobile-recovery-export-confirm'),
    );
    await tester.scrollUntilVisible(confirm, 120);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(
      harnessKey.currentState?.result,
      MobileRecoveryMediaExportResult.confirmed,
    );
  });
}

Widget _testApp(Widget home) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

Uint8List _encryptedMedia() {
  return Uint8List.fromList(
    List<int>.generate(644, (index) => (index * 37 + 11) & 0xff),
  );
}

final class _ExportHarness extends StatefulWidget {
  const _ExportHarness({
    super.key,
    required this.encryptedMedia,
    required this.fileSaver,
  });

  final Uint8List encryptedMedia;
  final MobileRecoveryMediaFileSaver fileSaver;

  @override
  State<_ExportHarness> createState() => _ExportHarnessState();
}

final class _ExportHarnessState extends State<_ExportHarness> {
  MobileRecoveryMediaExportResult? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey<String>('open-export-page'),
          onPressed: () async {
            final next = await Navigator.of(context)
                .push<MobileRecoveryMediaExportResult>(
                  MaterialPageRoute<MobileRecoveryMediaExportResult>(
                    builder: (_) => MobileRecoveryMediaExportPage(
                      encryptedMedia: widget.encryptedMedia,
                      fileSaver: widget.fileSaver,
                    ),
                  ),
                );
            if (mounted) setState(() => result = next);
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}
