import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import 'ios_tile_button.dart';

final class LocalCryptographicWipeGate extends StatefulWidget {
  const LocalCryptographicWipeGate({super.key, required this.retry});

  final Future<void> Function() retry;

  @override
  State<LocalCryptographicWipeGate> createState() =>
      _LocalCryptographicWipeGateState();
}

final class _LocalCryptographicWipeGateState
    extends State<LocalCryptographicWipeGate> {
  bool _retrying = false;
  bool _retryFailed = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    try {
      await widget.retry();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Kelivo local cryptographic wipe',
          context: ErrorDescription('while retrying local cryptographic wipe'),
        ),
      );
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _retryFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.shieldAlert,
                      size: 28,
                      color: colors.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.localDeviceWipeTitle,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.localDeviceWipeMessage,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  if (_retryFailed) ...[
                    const SizedBox(height: 14),
                    Text(
                      l10n.localDeviceWipeRetryFailed,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: IosTileButton(
                      label: l10n.localDeviceWipeRetry,
                      icon: LucideIcons.rotateCcw,
                      enabled: !_retrying,
                      backgroundColor: colors.error,
                      foregroundColor: colors.error,
                      onTap: () => unawaited(_retry()),
                    ),
                  ),
                  if (_retrying) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
