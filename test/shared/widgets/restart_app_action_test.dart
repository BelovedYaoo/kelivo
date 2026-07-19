import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/main.dart' show AssistantDefaultsBootstrap;
import 'package:Kelivo/shared/widgets/restart_app_action.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/utils/platform_utils.dart';

void main() {
  testWidgets('工作区切换待重启时全局门禁替代旧工作区内容', (tester) async {
    var oldWorkspaceTapCount = 0;
    var restartCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => AppSnackBarOverlay(child: child!),
        home: WorkspaceRestartGate(
          restartRequired: true,
          restart: () async => restartCount++,
          child: Scaffold(
            body: TextButton(
              onPressed: () => oldWorkspaceTapCount++,
              child: const Text('旧工作区操作'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('旧工作区操作'), findsNothing);
    expect(find.text('重启以切换工作区'), findsOneWidget);

    await tester.tap(find.text('重启 Kelivo'));
    await tester.pump();

    expect(oldWorkspaceTapCount, 0);
    expect(restartCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('重启请求返回但旧进程仍存活时恢复重试入口', (tester) async {
    var restartCount = 0;
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: WorkspaceRestartGate(
            restartRequired: true,
            restartWatchdogTimeout: const Duration(milliseconds: 10),
            restart: () async => restartCount++,
            child: const Text('Old workspace'),
          ),
        ),
      );

      await tester.tap(find.text('Restart Kelivo'));
      await tester.pump();

      expect(restartCount, 1);
      expect(reportedErrors, isEmpty);
      expect(
        find.text(
          'Kelivo could not restart automatically. Fully close it, then open it again.',
        ),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 10));

      expect(reportedErrors, hasLength(1));
      expect(reportedErrors.single.exception, isA<TimeoutException>());
      expect(
        find.text(
          'Kelivo could not restart automatically. Fully close it, then open it again.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Restart Kelivo'));
      await tester.pump();
      expect(restartCount, 2);

      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      FlutterError.onError = previousOnError;
    }
  });

  testWidgets('默认助手初始化失败会报告错误并单飞延迟重试', (tester) async {
    final bootstrap = AssistantDefaultsBootstrap(
      retryDelay: const Duration(milliseconds: 10),
    );
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    var attempts = 0;
    var activeAttempts = 0;
    var maxActiveAttempts = 0;

    Future<bool> initialize() async {
      attempts++;
      activeAttempts++;
      maxActiveAttempts = maxActiveAttempts < activeAttempts
          ? activeAttempts
          : maxActiveAttempts;
      try {
        if (attempts == 1) {
          throw StateError('injected_assistant_defaults_failure');
        }
        return true;
      } finally {
        activeAttempts--;
      }
    }

    FlutterError.onError = reportedErrors.add;
    try {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            bootstrap.schedule(initialize);
            bootstrap.schedule(initialize);
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pump();

      expect(attempts, 1);
      expect(reportedErrors, hasLength(1));
      expect(
        reportedErrors.single.exception,
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'injected_assistant_defaults_failure',
        ),
      );

      bootstrap.schedule(initialize);
      await tester.pump(const Duration(milliseconds: 9));
      expect(attempts, 1);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(attempts, 2);
      expect(maxActiveAttempts, 1);

      bootstrap.schedule(initialize);
      await tester.pump();
      expect(attempts, 2);
    } finally {
      FlutterError.onError = previousOnError;
    }
  });

  testWidgets('全局门禁不依赖旧工作区 Navigator 呈现重启失败', (tester) async {
    var restartCount = 0;
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => WorkspaceRestartGate(
            restartRequired: true,
            restart: () async {
              restartCount++;
              throw StateError('injected_restart_failure');
            },
            child: child!,
          ),
          home: const Text('Old workspace'),
        ),
      );

      await tester.tap(find.text('Restart Kelivo'));
      await tester.pump();

      expect(reportedErrors, hasLength(1));
      expect(find.text('Old workspace'), findsNothing);
      expect(
        find.text(
          'Kelivo could not restart automatically. Fully close it, then open it again.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Restart Kelivo'));
      await tester.pump();
      expect(restartCount, 2);
    } finally {
      FlutterError.onError = previousOnError;
    }
  });

  testWidgets('reports restart failure and keeps the retry dialog open', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => AppSnackBarOverlay(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Restart prompt'),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          if (await requestAppRestart(dialogContext, () async {
                                throw StateError('injected_restart_failure');
                              }) &&
                              dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    try {
      await tester.tap(find.text('Retry'));
      await tester.pump();
    } finally {
      FlutterError.onError = previousOnError;
    }

    expect(reportedErrors, hasLength(1));
    expect(find.text('Restart prompt'), findsOneWidget);
    expect(
      find.text(
        'Kelivo could not restart automatically. Fully close it, then open it again.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  group('PlatformUtils.restartApp', () {
    const restartChannel = MethodChannel('restart');
    final calls = <MethodCall>[];

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(restartChannel, (call) async {
            calls.add(call);
            return <String, Object?>{'success': true, 'mode': 'process'};
          });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(restartChannel, null);
    });

    for (final target in [TargetPlatform.windows, TargetPlatform.android]) {
      test('${target.name} 使用进程重启能力', () async {
        debugDefaultTargetPlatformOverride = target;

        await PlatformUtils.restartApp();

        expect(calls, hasLength(1));
        expect(calls.single.method, 'restartApp');
        expect(calls.single.arguments, containsPair('mode', 'process'));
      });
    }

    test('进程重启请求失败时向调用方报告错误', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(restartChannel, (call) async {
            calls.add(call);
            return <String, Object?>{
              'success': false,
              'mode': 'process',
              'code': 'RESTART_FAILED',
            };
          });

      await expectLater(
        PlatformUtils.restartApp(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restart_app:RESTART_FAILED',
          ),
        ),
      );
    });
  });
}
