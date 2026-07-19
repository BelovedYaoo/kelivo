import 'dart:async';

import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import 'ios_tile_button.dart';
import 'snackbar.dart';

class WorkspaceRestartGate extends StatefulWidget {
  const WorkspaceRestartGate({
    super.key,
    required this.restartRequired,
    required this.restart,
    required this.child,
    this.restartWatchdogTimeout = const Duration(seconds: 5),
  });

  final bool restartRequired;
  final Future<void> Function() restart;
  final Widget child;
  final Duration restartWatchdogTimeout;

  @override
  State<WorkspaceRestartGate> createState() => _WorkspaceRestartGateState();
}

class _WorkspaceRestartGateState extends State<WorkspaceRestartGate> {
  bool _restarting = false;
  bool _restartFailed = false;
  Timer? _restartWatchdog;

  @override
  void didUpdateWidget(covariant WorkspaceRestartGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.restartRequired && oldWidget.restartRequired) {
      _restartWatchdog?.cancel();
      _restartWatchdog = null;
      _restarting = false;
      _restartFailed = false;
    }
  }

  @override
  void dispose() {
    _restartWatchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.restartRequired) return widget.child;
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    // 工作区已经在持久层切换后，旧界面不能再获得任何交互机会。
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Lucide.RefreshCw, size: 42, color: colors.primary),
                    const SizedBox(height: 20),
                    Text(
                      l10n.cloudSyncWorkspaceRestartTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.cloudSyncWorkspaceRestartMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_restartFailed) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.restartAppFailedMessage,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: colors.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: IosTileButton(
                        label: l10n.cloudSyncWorkspaceRestartButton,
                        icon: Lucide.RefreshCw,
                        enabled: !_restarting,
                        backgroundColor: colors.primary,
                        foregroundColor: colors.primary,
                        onTap: _restart,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restart() async {
    if (_restarting) return;
    _restartWatchdog?.cancel();
    _restartWatchdog = null;
    setState(() {
      _restarting = true;
      _restartFailed = false;
    });
    try {
      await widget.restart();
      if (!mounted || !widget.restartRequired) return;
      // 成功的进程重启会在计时结束前终止旧进程；回调返回本身不是退出证据。
      _restartWatchdog = Timer(
        widget.restartWatchdogTimeout,
        _handleRestartWatchdogTimeout,
      );
    } catch (error, stackTrace) {
      _showRestartFailure(error, stackTrace);
    }
  }

  void _handleRestartWatchdogTimeout() {
    _restartWatchdog = null;
    _showRestartFailure(
      TimeoutException(
        'workspace_restart_process_exit_timeout',
        widget.restartWatchdogTimeout,
      ),
      StackTrace.current,
    );
  }

  void _showRestartFailure(Object error, StackTrace stackTrace) {
    _reportRestartFailure(error, stackTrace);
    if (!mounted) return;
    setState(() {
      _restarting = false;
      _restartFailed = true;
    });
  }
}

/// 请求进程重启；若平台无法安排重启，则保持当前重试界面可见。
Future<bool> requestAppRestart(
  BuildContext context,
  Future<void> Function() restart,
) async {
  try {
    await restart();
    return true;
  } catch (error, stackTrace) {
    _reportRestartFailure(error, stackTrace);
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.restartAppFailedMessage,
        type: NotificationType.error,
      );
    }
    return false;
  }
}

void _reportRestartFailure(Object error, StackTrace stackTrace) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'Kelivo restart',
      context: ErrorDescription('while requesting a process restart'),
    ),
  );
}
