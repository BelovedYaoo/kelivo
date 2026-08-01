import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:async';
import 'l10n/app_localizations.dart';
import 'features/home/pages/home_page.dart';
import 'desktop/desktop_home_page.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'desktop/desktop_window_controller.dart';
import 'desktop/desktop_tray_controller.dart';
// Theme is now managed in SettingsProvider
import 'theme/theme_factory.dart';
import 'theme/palettes.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/providers/chat_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/mcp_provider.dart';
import 'core/providers/tts_provider.dart';
import 'core/providers/assistant_provider.dart';
import 'core/providers/tag_provider.dart';
import 'core/providers/update_provider.dart';
import 'core/providers/quick_phrase_provider.dart';
import 'core/providers/instruction_injection_provider.dart';
import 'core/providers/instruction_injection_group_provider.dart';
import 'core/providers/world_book_provider.dart';
import 'core/providers/memory_provider.dart';
import 'core/providers/hotkey_provider.dart';
import 'core/providers/cloud_sync_provider.dart';
import 'core/database/app_database.dart';
import 'core/database/chat_database_gateway.dart';
import 'core/database/database_installation_gate.dart';
import 'core/database/sqlcipher_database_key.dart';
import 'core/services/chat/chat_service.dart';
import 'core/services/sync/cloud_sync_client.dart';
import 'core/services/sync/cloud_sync_types.dart';
import 'core/services/sync/e2ee_chat_content_runtime.dart';
import 'core/services/sync/e2ee_config_provider_binding.dart';
import 'core/services/sync/e2ee_device_pairing_membership_commit.dart';
import 'core/services/sync/e2ee_mobile_background_sync.dart';
import 'core/services/sync/sync_write_executor.dart';
import 'core/services/storage/durable_shared_preferences_eraser.dart';
import 'core/services/workspace/account_workspace_runtime.dart';
import 'core/services/workspace/device_state_blob_store.dart';
import 'core/services/workspace/installation_operation_lease.dart';
import 'core/services/workspace/local_cryptographic_wipe.dart';
import 'core/services/workspace/local_cryptographic_wipe_startup.dart';
import 'core/services/database_v2_rollout_ledger.dart';
import 'core/services/backup/restore_business_lease.dart';
import 'core/services/backup/restore_startup_gate.dart';
import 'core/services/backup/restore_receipt.dart';
import 'core/services/backup/plaintext_remote_backup_retirement.dart';
import 'core/services/mcp/mcp_tool_service.dart';
import 'features/home/services/ask_user_interaction_service.dart';
import 'features/home/services/tool_approval_service.dart';
import 'utils/platform_utils.dart';
import 'utils/app_directories.dart';
import 'utils/sandbox_path_resolver.dart';
import 'shared/widgets/app_overlays.dart';
import 'shared/widgets/local_cryptographic_wipe_gate.dart';
import 'shared/widgets/restore_failure_screen.dart';
import 'shared/widgets/restore_cold_restart_screen.dart';
import 'shared/widgets/restore_outcome_notice.dart';
import 'shared/widgets/restart_app_action.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_fonts/system_fonts.dart';
import 'dart:io'
    show
        Directory,
        File,
        Platform,
        pid,
        stderr; // kept for global override usage inside provider
import 'core/services/android_background.dart';
import 'core/services/notification_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

final RouteObserver<ModalRoute<dynamic>> routeObserver =
    RouteObserver<ModalRoute<dynamic>>();
bool _didCheckUpdates = false; // one-time update check flag
final AssistantDefaultsBootstrap _assistantDefaultsBootstrap =
    AssistantDefaultsBootstrap();
bool _didInitializeLocalizedDefaults = false;

final class AssistantDefaultsBootstrap {
  AssistantDefaultsBootstrap({this.retryDelay = const Duration(seconds: 2)})
    : assert(!retryDelay.isNegative);

  final Duration retryDelay;
  bool _completed = false;
  bool _inFlight = false;
  Timer? _retryTimer;
  Future<bool> Function()? _latestInitialization;

  void schedule(Future<bool> Function() initialize) {
    if (_completed) return;
    _latestInitialization = initialize;
    if (_inFlight || _retryTimer != null) return;
    _inFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_inFlight || _completed) return;
      unawaited(_runLatest());
    });
  }

  Future<void> _runLatest() async {
    final initialize = _latestInitialization;
    if (initialize == null) {
      _inFlight = false;
      return;
    }
    try {
      _completed = await initialize();
      _inFlight = false;
      if (_completed) _latestInitialization = null;
    } catch (error, stackTrace) {
      _inFlight = false;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Kelivo startup',
          context: ErrorDescription('while ensuring default assistants'),
        ),
      );
      if (_completed || _retryTimer != null) return;
      // 持续失败时限制为单个延迟重试，避免构建循环形成并发写入风暴。
      _retryTimer = Timer(retryDelay, () {
        _retryTimer = null;
        if (_completed || _inFlight || _latestInitialization == null) return;
        _inFlight = true;
        unawaited(_runLatest());
      });
    }
  }
}

Future<void> main() async {
  await runZoned(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final mobileBackgroundSyncScheduler =
          E2eeMobileBackgroundSyncScheduler.forCurrentPlatform();
      const secureCore = KelivoSecureCore();
      late final Directory installationRoot;
      late final KelivoCoreCapabilities secureCoreCapabilities;
      try {
        installationRoot = await AppDirectories.getInstallationRootDirectory();
        secureCoreCapabilities = await secureCore.getCapabilities();
      } catch (error) {
        stderr.writeln('[InstallationBootstrap] failed');
        await _initRestoreFailureWindow();
        runApp(
          _RestoreFailureApp(
            diagnosticCode: restoreFailureDiagnosticCode(error),
          ),
        );
        return;
      }
      final localCryptographicWipe = InstallationLocalCryptographicWipe(
        installationRoot: installationRoot,
        isSupported: secureCoreCapabilities.supportsInstallationRootWipe,
        applicationCacheDirectory: getApplicationCacheDirectory,
        deleteAllSecureSlots: secureCore.deleteAllSlots,
        wipeInstallationRoot: secureCore.wipeInstallationRoot,
        clearAllPreferences: _clearAllPreferencesForLocalWipe,
      );
      final installationOperationLease = InstallationOperationLease(
        installationRoot: installationRoot,
      );
      final localWipeStartup = LocalCryptographicWipeStartupCoordinator(
        installationOperationLease: installationOperationLease,
        localCryptographicWipe: localCryptographicWipe,
        stopBackgroundSync: () =>
            mobileBackgroundSyncScheduler.setEnabled(false),
      );
      late final InstallationBusinessLease installationBusinessLease;
      try {
        final admission = await localWipeStartup.admit();
        switch (admission) {
          case LocalCryptographicWipeBusinessReady(:final businessLease):
            installationBusinessLease = businessLease;
            break;
          case LocalCryptographicWipeRestartRequired():
            await PlatformUtils.restartApp();
            await _initRestoreFailureWindow();
            runApp(const _RestoreColdRestartApp());
            return;
        }
      } catch (_) {
        stderr.writeln('[LocalCryptographicWipe] failed');
        await _initRestoreFailureWindow();
        runApp(
          _LocalCryptographicWipeFailureApp(
            retry: () async {
              await localWipeStartup.retryPendingWipe();
              await PlatformUtils.restartApp();
            },
          ),
        );
        return;
      }
      final AccountWorkspaceRuntime workspaceRuntime;
      try {
        workspaceRuntime = await AccountWorkspaceRuntime.bootstrap(
          installationRoot: installationRoot,
        );
      } catch (error) {
        stderr.writeln('[AccountWorkspace] failed');
        await _initRestoreFailureWindow();
        runApp(
          _RestoreFailureApp(
            diagnosticCode: restoreFailureDiagnosticCode(error),
          ),
        );
        return;
      }
      try {
        await PlaintextRemoteBackupRetirement.retireCurrentInstallation(
          workspaceRuntime: workspaceRuntime,
        );
      } catch (error) {
        stderr.writeln('[PlaintextRemoteBackupRetirement] failed');
        try {
          await workspaceRuntime.close();
        } catch (_) {
          stderr.writeln('[AccountWorkspaceClose] failed');
        }
        await _initRestoreFailureWindow();
        runApp(
          _RestoreFailureApp(
            diagnosticCode: restoreFailureDiagnosticCode(error),
          ),
        );
        return;
      }
      final appDataDirectory = workspaceRuntime.current.dataDirectory;
      final databaseCipher = SqlCipherDatabaseKey.forWorkspace(
        workspaceRuntime.current.workspaceKey,
      );
      final databaseGateway = ChatDatabaseGateway(cipher: databaseCipher);
      final RestoreReceipt? restoreOutcome;
      try {
        // 租约通过内部注册表在整个进程期间保持归属，直到进程退出，
        // 防止另一个实例与业务 I/O 发生竞争。
        final businessLease = await RestoreBusinessLease.acquire(
          appDataDirectory: appDataDirectory,
        );
        await workspaceRuntime.discardPlaintextLocalState();
        restoreOutcome =
            await RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: appDataDirectory,
              cipher: databaseCipher,
              businessLease: businessLease,
            );
      } on RestoreColdRestartRequired {
        await _initRestoreFailureWindow();
        runApp(const _RestoreColdRestartApp());
        return;
      } catch (error) {
        stderr.writeln('[RestoreStartupGate] failed');
        await _initRestoreFailureWindow();
        runApp(
          _RestoreFailureApp(
            diagnosticCode: restoreFailureDiagnosticCode(error),
          ),
        );
        return;
      }
      // Trim Flutter global image cache to reduce memory pressure from large images
      try {
        PaintingBinding.instance.imageCache.maximumSize = 200;
        PaintingBinding.instance.imageCache.maximumSizeBytes =
            48 << 20; // ~48MB
      } catch (_) {}
      // Desktop (Windows) window setup: hide native title bar for custom Flutter bar
      await _initDesktopWindow();
      // Avoid preloading all system fonts at launch (huge memory on desktop)
      // Cache current Documents directory to fix sandboxed absolute paths on iOS
      await SandboxPathResolver.init();
      try {
        final installationReceipt = await DatabaseInstallationGate.ensureReady(
          appDataDirectory: appDataDirectory,
          cipher: databaseCipher,
          allowDatabaseIdentityChange:
              restoreOutcome?.selectedComponents.contains(
                RestoreComponent.database,
              ) ??
              false,
        );
        try {
          final rollout = DatabaseV2RolloutLedger.rolloutDecision(
            installationId: installationReceipt.installationId,
            enabledBasisPoints: const int.fromEnvironment(
              'KELIVO_DATABASE_V2_ROLLOUT_BASIS_POINTS',
              defaultValue: 10000,
            ),
          );
          if (rollout.enabled) {
            await DatabaseV2RolloutLedger(
              appDataDirectory,
            ).recordSuccessfulColdStart(
              coldStartId:
                  '$pid:${DateTime.now().toUtc().microsecondsSinceEpoch}',
              atUtc: DateTime.now().toUtc(),
            );
          }
        } catch (_) {
          // 本地推出证据仅用于支持和退役元数据。数据库准入结果仍是权威；
          // 台账失败只会禁用旧数据清理，不会阻塞用户。
          stderr.writeln('[DatabaseV2Rollout] failed');
        }
      } catch (error) {
        stderr.writeln('[DatabaseAdmission] failed');
        await _initRestoreFailureWindow();
        runApp(
          _RestoreFailureApp(
            diagnosticCode: restoreFailureDiagnosticCode(error),
          ),
        );
        return;
      }
      // Enable edge-to-edge to allow content under system bars (Android)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      final chatContentRuntime = _createE2eeChatContentRuntime(
        workspaceRuntime: workspaceRuntime,
        databaseGateway: databaseGateway,
      );
      runApp(
        MyApp(
          workspaceRuntime: workspaceRuntime,
          databaseGateway: databaseGateway,
          mobileBackgroundSyncScheduler: mobileBackgroundSyncScheduler,
          localCryptographicWipe: localCryptographicWipe,
          installationOperationLease: installationOperationLease,
          installationBusinessLease: installationBusinessLease,
          chatContentRuntime: chatContentRuntime,
          restoreOutcome: restoreOutcome?.state,
        ),
      );
    },
    zoneSpecification: ZoneSpecification(
      // 第三方组件的自由文本无法证明已脱敏，生产 Zone 不向系统日志转发。
      print: (self, parent, zone, line) {},
    ),
  );
}

Future<void> _clearAllPreferencesForLocalWipe() =>
    const DurableSharedPreferencesEraser().eraseAll();

E2eeChatContentRuntime? _createE2eeChatContentRuntime({
  required AccountWorkspaceRuntime workspaceRuntime,
  required ChatDatabaseGateway databaseGateway,
}) {
  final session = workspaceRuntime.current.session;
  if (session == null ||
      session.baseUrl != defaultCloudSyncBaseUrl ||
      session.isExpiredAt(DateTime.now().toUtc())) {
    return null;
  }
  return E2eeChatContentRuntime.takeOwnership(
    session: session,
    deviceStateStore: DeviceStateBlobStore(
      installationRoot: workspaceRuntime.installationRoot,
    ),
    secureCore: const KelivoSecureCore(),
    databaseGateway: databaseGateway,
    databaseFile: _currentAccountDatabaseFile(workspaceRuntime),
    client: CloudSyncClient(token: session.token),
  );
}

File _currentAccountDatabaseFile(AccountWorkspaceRuntime workspaceRuntime) =>
    File(
      '${workspaceRuntime.current.dataDirectory.path}'
      '${Platform.pathSeparator}${AppDatabase.databaseFileName}',
    );

Future<void> _initRestoreFailureWindow() async {
  if (kIsWeb) return;
  final isDesktop =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  if (!isDesktop) return;
  try {
    await windowManager.ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.show();
      await windowManager.focus();
      return;
    }
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(title: 'Kelivo'),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  } catch (_) {
    stderr.writeln('[RestoreFailureWindow] failed');
  }
}

class _RestoreFailureApp extends StatelessWidget {
  const _RestoreFailureApp({required this.diagnosticCode});

  final String diagnosticCode;

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalettes.defaultPalette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kelivo',
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildLightThemeForScheme(palette.light),
      darkTheme: buildDarkThemeForScheme(palette.dark),
      home: RestoreFailureScreen(
        diagnosticCode: diagnosticCode,
        restart: PlatformUtils.restartApp,
      ),
    );
  }
}

class _LocalCryptographicWipeFailureApp extends StatelessWidget {
  const _LocalCryptographicWipeFailureApp({required this.retry});

  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalettes.defaultPalette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kelivo',
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildLightThemeForScheme(palette.light),
      darkTheme: buildDarkThemeForScheme(palette.dark),
      home: LocalCryptographicWipeGate(retry: retry),
    );
  }
}

class _RestoreColdRestartApp extends StatelessWidget {
  const _RestoreColdRestartApp();

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalettes.defaultPalette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kelivo',
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildLightThemeForScheme(palette.light),
      darkTheme: buildDarkThemeForScheme(palette.dark),
      home: const RestoreColdRestartScreen(restart: PlatformUtils.restartApp),
    );
  }
}

Future<void> _initDesktopWindow() async {
  if (kIsWeb) return;
  try {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await windowManager.ensureInitialized();
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    // Initialize and show desktop window with persisted size/position
    await DesktopWindowController.instance.initializeAndShow(title: 'Kelivo');
  } catch (_) {
    // Ignore on unsupported platforms.
  }
}

// Removed eager system font preloading to reduce memory footprint at launch.

class MyApp extends StatelessWidget {
  const MyApp({
    required this.workspaceRuntime,
    required this.databaseGateway,
    required this.mobileBackgroundSyncScheduler,
    required this.localCryptographicWipe,
    required this.installationOperationLease,
    required this.installationBusinessLease,
    super.key,
    this.chatContentRuntime,
    this.restoreOutcome,
  });

  final AccountWorkspaceRuntime workspaceRuntime;
  final ChatDatabaseGateway databaseGateway;
  final E2eeMobileBackgroundSyncScheduler mobileBackgroundSyncScheduler;
  final LocalCryptographicWipe localCryptographicWipe;
  final InstallationOperationLease installationOperationLease;
  final InstallationBusinessLease installationBusinessLease;
  final E2eeChatContentRuntime? chatContentRuntime;
  final RestoreReceiptState? restoreOutcome;

  @override
  Widget build(BuildContext context) {
    const localSyncWriteExecutor = LocalOnlySyncWriteExecutor();
    final chatSyncWriteExecutor = chatContentRuntime ?? localSyncWriteExecutor;
    final SyncWriteExecutor configSyncWriteExecutor =
        chatContentRuntime ?? localSyncWriteExecutor;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) =>
              UserProvider(syncWriteExecutor: configSyncWriteExecutor),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) {
            final settings = SettingsProvider(
              syncWriteExecutor: configSyncWriteExecutor,
            );
            unawaited(settings.incrementAppLaunchCount());
            return settings;
          },
        ),
        ChangeNotifierProvider(
          // 云同步 Provider 会立即初始化内容运行时，因此聊天服务必须先完成绑定。
          lazy: false,
          create: (_) {
            final chatService = ChatService(
              chatSyncWriteExecutor,
              databaseGateway: databaseGateway,
            );
            chatContentRuntime?.bindChatService(chatService);
            return chatService;
          },
        ),
        ChangeNotifierProvider(create: (_) => McpToolService()),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) =>
              McpProvider(syncWriteExecutor: configSyncWriteExecutor),
        ),
        ChangeNotifierProvider(create: (_) => ToolApprovalService()),
        ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ChangeNotifierProvider(
          lazy: false,
          create: (ctx) => AssistantProvider(
            chatService: ctx.read<ChatService>(),
            syncWriteExecutor: configSyncWriteExecutor,
          ),
        ),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => TtsProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) =>
              QuickPhraseProvider(syncWriteExecutor: configSyncWriteExecutor),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => InstructionInjectionProvider(
            syncWriteExecutor: configSyncWriteExecutor,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => InstructionInjectionGroupProvider(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) =>
              WorldBookProvider(syncWriteExecutor: configSyncWriteExecutor),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) =>
              MemoryProvider(syncWriteExecutor: configSyncWriteExecutor),
        ),
        Provider<E2eeConfigProviderBinding>(
          lazy: false,
          create: (ctx) {
            final binding = E2eeConfigProviderBinding(
              settingsProvider: ctx.read<SettingsProvider>(),
              assistantProvider: ctx.read<AssistantProvider>(),
              memoryProvider: ctx.read<MemoryProvider>(),
              mcpProvider: ctx.read<McpProvider>(),
              quickPhraseProvider: ctx.read<QuickPhraseProvider>(),
              instructionInjectionProvider: ctx
                  .read<InstructionInjectionProvider>(),
              worldBookProvider: ctx.read<WorldBookProvider>(),
              userProvider: ctx.read<UserProvider>(),
            );
            chatContentRuntime?.bindConfigProviders(binding);
            return binding;
          },
        ),
        // Desktop hotkeys provider
        ChangeNotifierProvider(create: (_) => HotkeyProvider()),
        ChangeNotifierProvider(
          lazy: false,
          create: (ctx) {
            ctx.read<E2eeConfigProviderBinding>();
            final runtime = chatContentRuntime;
            final provider = runtime == null
                ? CloudSyncProvider.controlPlaneOnly(
                    workspaceRuntime,
                    localCryptographicWipe: localCryptographicWipe,
                    installationOperationLease: installationOperationLease,
                    installationBusinessLease: installationBusinessLease,
                    stopBackgroundSync: () =>
                        mobileBackgroundSyncScheduler.setEnabled(false),
                    restartForLocalDeviceWipe: PlatformUtils.restartApp,
                  )
                : CloudSyncProvider.withContentRuntime(
                    workspaceRuntime,
                    contentRuntime: runtime,
                    devicePairingMembershipCommitPreparer:
                        E2eeDevicePairingMembershipCommitCoordinator(
                          databaseGateway,
                          databaseFile: _currentAccountDatabaseFile(
                            workspaceRuntime,
                          ),
                        ),
                    localCryptographicWipe: localCryptographicWipe,
                    installationOperationLease: installationOperationLease,
                    installationBusinessLease: installationBusinessLease,
                    stopBackgroundSync: () =>
                        mobileBackgroundSyncScheduler.setEnabled(false),
                    restartForLocalDeviceWipe: PlatformUtils.restartApp,
                  );
            unawaited(provider.initialize());
            return provider;
          },
        ),
        Provider<E2eeMobileBackgroundSyncLifecycle>(
          lazy: false,
          create: (ctx) => E2eeMobileBackgroundSyncLifecycle(
            accountState: ctx.read<CloudSyncProvider>(),
            scheduler: mobileBackgroundSyncScheduler,
          ),
          dispose: (_, lifecycle) => lifecycle.dispose(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final settings = context.watch<SettingsProvider>();
          final workspaceRestartRequired = context
              .select<CloudSyncProvider, bool>(
                (provider) => provider.workspaceRestartRequired,
              );
          final localDeviceWipePending = context
              .select<CloudSyncProvider, bool>(
                (provider) => provider.localDeviceWipePending,
              );
          // Apply global proxy overrides when settings change
          settings.applyGlobalProxyOverridesIfNeeded();
          // Lazily ensure system fonts only if user selected a system family (desktop only)
          // Load ONLY selected families to avoid huge memory from loading all system fonts.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              final isDesktop =
                  !kIsWeb &&
                  (defaultTargetPlatform == TargetPlatform.windows ||
                      defaultTargetPlatform == TargetPlatform.macOS ||
                      defaultTargetPlatform == TargetPlatform.linux);
              if (!isDesktop) return;
              // Selected system app/code fonts (not Google, not local alias)
              final wantsAppSystem =
                  (settings.appFontFamily?.isNotEmpty == true) &&
                  !settings.appFontIsGoogle &&
                  (settings.appFontLocalAlias == null ||
                      settings.appFontLocalAlias!.isEmpty);
              final wantsCodeSystem =
                  (settings.codeFontFamily?.isNotEmpty == true) &&
                  !settings.codeFontIsGoogle &&
                  (settings.codeFontLocalAlias == null ||
                      settings.codeFontLocalAlias!.isEmpty);
              if (wantsAppSystem || wantsCodeSystem) {
                final sf = SystemFonts();
                if (wantsAppSystem) {
                  final fam = settings.appFontFamily!;
                  try {
                    await sf.loadFont(fam);
                  } catch (_) {}
                }
                if (wantsCodeSystem) {
                  final fam = settings.codeFontFamily!;
                  try {
                    if (fam != settings.appFontFamily) await sf.loadFont(fam);
                  } catch (_) {}
                }
              }
            } catch (_) {}
          });
          // One-time app update check after first build
          if (settings.showAppUpdates && !_didCheckUpdates) {
            _didCheckUpdates = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                context.read<UpdateProvider>().checkForUpdates();
              } catch (_) {}
            });
          }
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              final isAndroid =
                  Theme.of(context).platform == TargetPlatform.android;
              // Update dynamic color capability for settings UI (avoid notify during build)
              final dynSupported =
                  isAndroid && (lightDynamic != null || darkDynamic != null);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  settings.setDynamicColorSupported(dynSupported);
                } catch (_) {}
              });

              // Initialize desktop hotkeys on supported platforms
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  final isDesktop =
                      !kIsWeb &&
                      (defaultTargetPlatform == TargetPlatform.windows ||
                          defaultTargetPlatform == TargetPlatform.macOS ||
                          defaultTargetPlatform == TargetPlatform.linux);
                  if (isDesktop) {
                    await context.read<HotkeyProvider>().initialize();
                  }
                } catch (_) {}
              });

              // Android-only: ensure background execution matches setting and prepare notifications if needed
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  if (Platform.isAndroid) {
                    final mode = settings.androidBackgroundChatMode;
                    if (mode != AndroidBackgroundChatMode.off) {
                      final l10n = AppLocalizations.of(context);
                      if (l10n == null) return;
                      // Enable only if currently disabled to avoid duplicate ROM prompts
                      try {
                        final already =
                            await AndroidBackgroundManager.isEnabled();
                        if (!already) {
                          await AndroidBackgroundManager.ensureInitialized(
                            notificationTitle:
                                l10n.androidBackgroundNotificationTitle,
                            notificationText:
                                l10n.androidBackgroundNotificationText,
                          );
                          await AndroidBackgroundManager.setEnabled(true);
                        }
                      } catch (_) {}
                      if (mode == AndroidBackgroundChatMode.onNotify) {
                        await NotificationService.ensureInitialized();
                        await NotificationService.ensureAndroidNotificationsPermission();
                      }
                    }
                  }
                } catch (_) {}
              });

              final useDyn = isAndroid && settings.useDynamicColor;
              final palette = ThemePalettes.byId(settings.themePaletteId);

              final light = buildLightThemeForScheme(
                palette.light,
                dynamicScheme: useDyn ? lightDynamic : null,
                pureBackground: settings.usePureBackground,
              );
              final dark = buildDarkThemeForScheme(
                palette.dark,
                dynamicScheme: useDyn ? darkDynamic : null,
                pureBackground: settings.usePureBackground,
              );
              // Resolve effective app font family (system/Google/local alias)
              String? effectiveAppFontFamily() {
                final fam = settings.appFontFamily;
                if (fam == null || fam.isEmpty) return null;
                if (settings.appFontIsGoogle) {
                  try {
                    final s = GoogleFonts.getFont(fam);
                    return s.fontFamily ?? fam;
                  } catch (_) {
                    return fam;
                  }
                }
                return fam;
              }

              final effectiveAppFont = effectiveAppFontFamily();

              // Apply user-selected app font to theme text styles and app bar
              ThemeData applyAppFont(ThemeData base) {
                if (effectiveAppFont == null || effectiveAppFont.isEmpty) {
                  return base;
                }
                TextStyle? withFamily(TextStyle? s) =>
                    s?.copyWith(fontFamily: effectiveAppFont);
                TextTheme apply(TextTheme t) => t.copyWith(
                  displayLarge: withFamily(t.displayLarge),
                  displayMedium: withFamily(t.displayMedium),
                  displaySmall: withFamily(t.displaySmall),
                  headlineLarge: withFamily(t.headlineLarge),
                  headlineMedium: withFamily(t.headlineMedium),
                  headlineSmall: withFamily(t.headlineSmall),
                  titleLarge: withFamily(t.titleLarge),
                  titleMedium: withFamily(t.titleMedium),
                  titleSmall: withFamily(t.titleSmall),
                  bodyLarge: withFamily(t.bodyLarge),
                  bodyMedium: withFamily(t.bodyMedium),
                  bodySmall: withFamily(t.bodySmall),
                  labelLarge: withFamily(t.labelLarge),
                  labelMedium: withFamily(t.labelMedium),
                  labelSmall: withFamily(t.labelSmall),
                );
                final bar = base.appBarTheme;
                final appBar = bar.copyWith(
                  titleTextStyle: (bar.titleTextStyle ?? const TextStyle())
                      .copyWith(fontFamily: effectiveAppFont),
                  toolbarTextStyle: (bar.toolbarTextStyle ?? const TextStyle())
                      .copyWith(fontFamily: effectiveAppFont),
                );
                // Apply as default family to all text in ThemeData
                return base.copyWith(
                  textTheme: apply(base.textTheme),
                  primaryTextTheme: apply(base.primaryTextTheme),
                  appBarTheme: appBar,
                );
              }

              final themedLight = applyAppFont(light);
              final themedDark = applyAppFont(dark);
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Kelivo',
                // App UI language; null = follow system (respects iOS per-app language)
                locale: settings.appLocaleForMaterialApp,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: themedLight,
                darkTheme: themedDark,
                themeMode: settings.themeMode,
                navigatorObservers: <NavigatorObserver>[routeObserver],
                home: RestoreOutcomeNotice(
                  outcome: restoreOutcome,
                  child: _selectHome(),
                ),
                builder: (ctx, child) {
                  final bright = Theme.of(ctx).brightness;
                  final overlay = bright == Brightness.dark
                      ? const SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: Brightness.light,
                          statusBarBrightness: Brightness.dark,
                          systemNavigationBarColor: Colors.transparent,
                          systemNavigationBarIconBrightness: Brightness.light,
                          systemNavigationBarDividerColor: Colors.transparent,
                          systemNavigationBarContrastEnforced: false,
                        )
                      : const SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: Brightness.dark,
                          statusBarBrightness: Brightness.light,
                          systemNavigationBarColor: Colors.transparent,
                          systemNavigationBarIconBrightness: Brightness.dark,
                          systemNavigationBarDividerColor: Colors.transparent,
                          systemNavigationBarContrastEnforced: false,
                        );
                  if (!_didInitializeLocalizedDefaults) {
                    _didInitializeLocalizedDefaults = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      try {
                        ctx.read<ChatService>().setDefaultConversationTitle(
                          AppLocalizations.of(
                            ctx,
                          )!.chatServiceDefaultConversationTitle,
                        );
                      } catch (_) {}
                      try {
                        ctx.read<UserProvider>().setDefaultNameIfUnset(
                          AppLocalizations.of(ctx)!.userProviderDefaultUserName,
                        );
                      } catch (_) {}
                    });
                  }
                  _assistantDefaultsBootstrap.schedule(() async {
                    if (!ctx.mounted) return false;
                    await ctx.read<AssistantProvider>().ensureDefaults(ctx);
                    return true;
                  });

                  // Desktop tray + close behaviour (minimize to tray) sync
                  final l10n = AppLocalizations.of(ctx);
                  if (l10n != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      try {
                        final isDesktop =
                            !kIsWeb &&
                            (defaultTargetPlatform == TargetPlatform.windows ||
                                defaultTargetPlatform == TargetPlatform.macOS ||
                                defaultTargetPlatform == TargetPlatform.linux);
                        if (!isDesktop) return;
                        final sp = ctx.read<SettingsProvider>();
                        await DesktopTrayController.instance.syncFromSettings(
                          l10n,
                          showTray: sp.desktopShowTray,
                          minimizeToTrayOnClose:
                              sp.desktopMinimizeToTrayOnClose,
                        );
                      } catch (_) {}
                    });
                  }

                  // Enforce app font as a default across the tree for Texts without explicit family
                  final appWithOverlays = localDeviceWipePending
                      ? LocalCryptographicWipeGate(
                          retry: () async {
                            final completed = await ctx
                                .read<CloudSyncProvider>()
                                .retryLocalDeviceWipe();
                            if (!completed) {
                              throw StateError('local_device_wipe_incomplete');
                            }
                          },
                        )
                      : WorkspaceRestartGate(
                          restartRequired: workspaceRestartRequired,
                          restart: () async {
                            await ctx
                                .read<CloudSyncProvider>()
                                .prepareWorkspaceRestart();
                            await PlatformUtils.restartApp();
                          },
                          child: AppOverlays(
                            child: child ?? const SizedBox.shrink(),
                          ),
                        );
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: overlay,
                    child: effectiveAppFont == null
                        ? appWithOverlays
                        : DefaultTextStyle.merge(
                            style: TextStyle(fontFamily: effectiveAppFont),
                            child: appWithOverlays,
                          ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

Widget _selectHome() {
  // Mobile remains the default platform. Desktop is an added platform.
  if (kIsWeb) return const HomePage();
  final isDesktop =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
  return isDesktop ? const DesktopHomePage() : const HomePage();
}

// Overrides logic is implemented within SettingsProvider now.
