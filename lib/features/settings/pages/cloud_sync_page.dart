import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/cloud_sync_provider.dart';
import '../../../core/services/sync/cloud_sync_types.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';

class CloudSyncPage extends StatelessWidget {
  const CloudSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          minSize: 44,
          semanticLabel: l10n.settingsPageBackButton,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.cloudSyncTitle),
      ),
      body: const CloudSyncSettingsContent(),
    );
  }
}

class CloudSyncSettingsContent extends StatefulWidget {
  const CloudSyncSettingsContent({super.key, this.desktop = false});

  final bool desktop;

  @override
  State<CloudSyncSettingsContent> createState() =>
      _CloudSyncSettingsContentState();
}

class _CloudSyncSettingsContentState extends State<CloudSyncSettingsContent> {
  final TextEditingController _serviceUrlController = TextEditingController();
  final TextEditingController _loginNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();

  bool _serviceUrlEdited = false;
  bool _deviceNameInitialized = false;
  String? _requestedDeviceScope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deviceNameInitialized) return;
    final l10n = AppLocalizations.of(context)!;
    _deviceNameController.text = l10n.cloudSyncDefaultDeviceName(
      _currentPlatformLabel(l10n),
    );
    _deviceNameInitialized = true;
  }

  @override
  void dispose() {
    _serviceUrlController.dispose();
    _loginNameController.dispose();
    _passwordController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CloudSyncProvider>();
    final session = provider.session;
    final rememberedUrl = provider.lastBaseUrl;
    if (!_serviceUrlEdited &&
        _serviceUrlController.text.isEmpty &&
        rememberedUrl != null) {
      _serviceUrlController.text = rememberedUrl;
    }

    if (session == null) {
      _requestedDeviceScope = null;
    } else if (_requestedDeviceScope != session.accountScope) {
      _requestedDeviceScope = session.accountScope;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.read<CloudSyncProvider>().signedIn) {
          unawaited(context.read<CloudSyncProvider>().refreshDevices());
        }
      });
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        widget.desktop ? 0 : 16,
        12,
        widget.desktop ? 0 : 16,
        24,
      ),
      children: [
        if (provider.lastError case final error?) ...[
          _ErrorCard(
            title: AppLocalizations.of(context)!.cloudSyncErrorTitle,
            message: cloudSyncFailureText(AppLocalizations.of(context)!, error),
          ),
          const SizedBox(height: 12),
        ],
        if (session == null)
          _buildSignInSection(context, provider)
        else ...[
          _buildAccountSection(context, provider, session),
          const SizedBox(height: 14),
          _buildDevicesSection(context, provider),
        ],
      ],
    );
  }

  Widget _buildSignInSection(BuildContext context, CloudSyncProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final busy =
        provider.status == CloudSyncProviderStatus.initializing ||
        provider.status == CloudSyncProviderStatus.signingIn;
    return _Section(
      title: l10n.cloudSyncSignInSection,
      children: [
        IosFormTextField(
          label: l10n.cloudSyncServiceUrl,
          controller: _serviceUrlController,
          inlineLabel: widget.desktop,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          enabled: !busy,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => _serviceUrlEdited = true,
        ),
        const _SectionDivider(),
        IosFormTextField(
          label: l10n.cloudSyncLoginName,
          controller: _loginNameController,
          inlineLabel: widget.desktop,
          textInputAction: TextInputAction.next,
          enabled: !busy,
          autocorrect: false,
          enableSuggestions: false,
        ),
        const _SectionDivider(),
        IosFormTextField(
          label: l10n.cloudSyncPassword,
          controller: _passwordController,
          inlineLabel: widget.desktop,
          textInputAction: TextInputAction.next,
          enabled: !busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
        ),
        const _SectionDivider(),
        IosFormTextField(
          label: l10n.cloudSyncDeviceName,
          controller: _deviceNameController,
          inlineLabel: widget.desktop,
          textInputAction: TextInputAction.done,
          enabled: !busy,
        ),
        const _SectionDivider(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: IosTileButton(
              label: provider.status == CloudSyncProviderStatus.signingIn
                  ? l10n.cloudSyncSigningIn
                  : l10n.cloudSyncSignIn,
              icon: Lucide.User,
              enabled: !busy,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.primary,
              onTap: () => unawaited(_signIn()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    CloudSyncProvider provider,
    CloudSyncAccountSession session,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final status = provider.status;
    final busy =
        status == CloudSyncProviderStatus.signingOut ||
        status == CloudSyncProviderStatus.signingIn;
    final syncing = status == CloudSyncProviderStatus.syncing;
    return _Section(
      title: l10n.cloudSyncAccountSection,
      children: [
        _InfoRow(
          label: l10n.cloudSyncAccount,
          value: session.displayName,
          detail: session.loginName,
        ),
        const _SectionDivider(),
        _InfoRow(label: l10n.cloudSyncService, value: session.baseUrl),
        const _SectionDivider(),
        _InfoRow(
          label: l10n.cloudSyncStatus,
          value: cloudSyncStatusText(l10n, status),
        ),
        const _SectionDivider(),
        _InfoRow(
          label: l10n.cloudSyncLastSync,
          value: _formatDateTime(context, provider.lastRun?.completedAt),
        ),
        const _SectionDivider(),
        _SwitchRow(
          label: l10n.cloudSyncPause,
          detail: l10n.cloudSyncPauseDescription,
          value: provider.paused,
          enabled: !busy,
          onChanged: (value) => unawaited(_setPaused(value)),
        ),
        const _SectionDivider(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: IosTileButton(
                  label: syncing
                      ? l10n.cloudSyncSyncing
                      : l10n.cloudSyncSyncNow,
                  icon: Lucide.RefreshCw,
                  enabled: !busy && !provider.paused && !syncing,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  onTap: () => unawaited(_syncNow()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: IosTileButton(
                  label: l10n.cloudSyncLogout,
                  icon: Lucide.X,
                  enabled: !busy,
                  foregroundColor: Theme.of(context).colorScheme.error,
                  borderColor: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.35),
                  onTap: () => unawaited(_signOut()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesSection(
    BuildContext context,
    CloudSyncProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SectionHeader(l10n.cloudSyncDevicesSection)),
            IosIconButton(
              icon: Lucide.RefreshCw,
              semanticLabel: l10n.cloudSyncRefreshDevices,
              enabled: !provider.devicesLoading,
              onTap: () => unawaited(provider.refreshDevices()),
            ),
          ],
        ),
        if (provider.deviceError case final error?) ...[
          const SizedBox(height: 6),
          _ErrorCard(
            title: l10n.cloudSyncErrorTitle,
            message: cloudSyncFailureText(l10n, error),
          ),
          const SizedBox(height: 10),
        ],
        _SectionCard(
          children: [
            if (provider.devicesLoading && provider.devices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.devices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  l10n.cloudSyncNoDevices,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              )
            else
              for (int index = 0; index < provider.devices.length; index++) ...[
                _DeviceRow(
                  device: provider.devices[index],
                  onRevoke: () =>
                      unawaited(_revokeDevice(provider.devices[index])),
                ),
                if (index != provider.devices.length - 1)
                  const _SectionDivider(),
              ],
          ],
        ),
      ],
    );
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context)!;
    final serviceUrl = _serviceUrlController.text.trim();
    final loginName = _loginNameController.text.trim();
    final password = _passwordController.text;
    final deviceName = _deviceNameController.text.trim();
    if (serviceUrl.isEmpty ||
        loginName.isEmpty ||
        password.isEmpty ||
        deviceName.isEmpty) {
      showAppSnackBar(
        context,
        message: l10n.cloudSyncRequiredFields,
        type: NotificationType.warning,
      );
      return;
    }

    final provider = context.read<CloudSyncProvider>();
    final success = await provider.login(
      baseUrl: serviceUrl,
      loginName: loginName,
      password: password,
      deviceName: deviceName,
    );
    if (!mounted) return;
    if (success) {
      _passwordController.clear();
      return;
    }
    showAppSnackBar(
      context,
      message: cloudSyncFailureText(
        l10n,
        provider.lastError ??
            const CloudSyncException(
              kind: CloudSyncFailureKind.unknown,
              retryable: false,
            ),
      ),
      type: NotificationType.error,
    );
  }

  Future<void> _setPaused(bool value) async {
    final provider = context.read<CloudSyncProvider>();
    if (await provider.setPaused(value) || !mounted) return;
    showAppSnackBar(
      context,
      message: cloudSyncFailureText(
        AppLocalizations.of(context)!,
        provider.lastError ??
            const CloudSyncException(
              kind: CloudSyncFailureKind.unknown,
              retryable: false,
            ),
      ),
      type: NotificationType.error,
    );
  }

  Future<void> _syncNow() async {
    final provider = context.read<CloudSyncProvider>();
    final success = await provider.syncNow();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      message: success
          ? l10n.cloudSyncSyncCompleted
          : cloudSyncFailureText(
              l10n,
              provider.lastError ??
                  const CloudSyncException(
                    kind: CloudSyncFailureKind.unknown,
                    retryable: false,
                  ),
            ),
      type: success ? NotificationType.success : NotificationType.error,
    );
  }

  Future<void> _revokeDevice(CloudSyncDeviceSession device) async {
    final confirmed = await _showRevokeDialog(device);
    if (confirmed != true || !mounted) return;
    final provider = context.read<CloudSyncProvider>();
    final success = await provider.revokeDevice(device.id);
    if (!mounted || success) return;
    showAppSnackBar(
      context,
      message: cloudSyncFailureText(
        AppLocalizations.of(context)!,
        provider.deviceError ??
            const CloudSyncException(
              kind: CloudSyncFailureKind.unknown,
              retryable: false,
            ),
      ),
      type: NotificationType.error,
    );
  }

  Future<bool?> _showRevokeDialog(CloudSyncDeviceSession device) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => _CloudSyncDialog(
        title: l10n.cloudSyncRevokeTitle,
        message: device.isCurrent
            ? l10n.cloudSyncRevokeCurrentMessage
            : l10n.cloudSyncRevokeMessage,
        actions: [
          IosTileButton(
            label: l10n.cloudSyncRevoke,
            icon: Lucide.X,
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
          IosTileButton(
            label: l10n.cloudSyncCancel,
            icon: Lucide.ArrowLeft,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final choice = await _showLogoutDialog();
    if (choice == null || !mounted) return;
    final provider = context.read<CloudSyncProvider>();
    final success = await provider.logout(
      clearSyncState: choice == _LogoutChoice.clearState,
    );
    if (!mounted || success) return;
    showAppSnackBar(
      context,
      message: cloudSyncFailureText(
        AppLocalizations.of(context)!,
        provider.lastError ??
            const CloudSyncException(
              kind: CloudSyncFailureKind.unknown,
              retryable: false,
            ),
      ),
      type: NotificationType.error,
    );
  }

  Future<_LogoutChoice?> _showLogoutDialog() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<_LogoutChoice>(
      context: context,
      builder: (dialogContext) => _CloudSyncDialog(
        title: l10n.cloudSyncLogoutTitle,
        message: l10n.cloudSyncLogoutMessage,
        actions: [
          IosTileButton(
            label: l10n.cloudSyncLogoutKeepState,
            icon: Lucide.Check,
            backgroundColor: Theme.of(dialogContext).colorScheme.primary,
            foregroundColor: Theme.of(dialogContext).colorScheme.primary,
            onTap: () =>
                Navigator.of(dialogContext).pop(_LogoutChoice.keepState),
          ),
          IosTileButton(
            label: l10n.cloudSyncLogoutClearState,
            icon: Lucide.Trash,
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
            borderColor: Theme.of(
              dialogContext,
            ).colorScheme.error.withValues(alpha: 0.35),
            onTap: () =>
                Navigator.of(dialogContext).pop(_LogoutChoice.clearState),
          ),
          IosTileButton(
            label: l10n.cloudSyncCancel,
            icon: Lucide.ArrowLeft,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
}

enum _LogoutChoice { keepState, clearState }

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title),
        const SizedBox(height: 6),
        _SectionCard(children: children),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.06),
          width: 0.6,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 12,
      endIndent: 12,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.32),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFontWeights.medium,
                color: cs.onSurface.withValues(alpha: 0.84),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SelectableText(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.medium,
                    color: cs.onSurface,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.58),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.medium,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IosSwitch(
            value: value,
            semanticLabel: label,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.onRevoke});

  final CloudSyncDeviceSession device;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final active = device.status == CloudSyncDeviceStatus.active;
    final statusLabel = device.isCurrent
        ? l10n.cloudSyncCurrentDevice
        : active
        ? l10n.cloudSyncActiveDevice
        : l10n.cloudSyncRevokedDevice;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Lucide.Monitor, size: 19, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${cloudSyncPlatformText(l10n, device.platform)} · '
                  '$statusLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.cloudSyncVersion} ${device.clientVersion} · '
                  '${l10n.cloudSyncLastSeen} '
                  '${_formatDateTime(context, device.lastSeenAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.52),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (active)
            IosTileButton(
              label: l10n.cloudSyncRevoke,
              icon: Lucide.X,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              foregroundColor: cs.error,
              borderColor: cs.error.withValues(alpha: 0.35),
              onTap: onRevoke,
            ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Lucide.MessageCircleWarning, size: 19, color: cs.error),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onErrorContainer.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudSyncDialog extends StatelessWidget {
  const _CloudSyncDialog({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 18),
              for (int index = 0; index < actions.length; index++) ...[
                actions[index],
                if (index != actions.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String cloudSyncStatusText(
  AppLocalizations l10n,
  CloudSyncProviderStatus status,
) {
  return switch (status) {
    CloudSyncProviderStatus.initializing => l10n.cloudSyncStatusInitializing,
    CloudSyncProviderStatus.signedOut => l10n.cloudSyncStatusSignedOut,
    CloudSyncProviderStatus.signingIn => l10n.cloudSyncStatusSigningIn,
    CloudSyncProviderStatus.signingOut => l10n.cloudSyncStatusSigningOut,
    CloudSyncProviderStatus.idle => l10n.cloudSyncStatusIdle,
    CloudSyncProviderStatus.syncing => l10n.cloudSyncStatusSyncing,
    CloudSyncProviderStatus.paused => l10n.cloudSyncStatusPaused,
    CloudSyncProviderStatus.error => l10n.cloudSyncStatusError,
  };
}

String cloudSyncFailureText(AppLocalizations l10n, CloudSyncException error) {
  return switch (error.kind) {
    CloudSyncFailureKind.invalidBaseUrl => l10n.cloudSyncFailureInvalidBaseUrl,
    CloudSyncFailureKind.unauthenticated =>
      l10n.cloudSyncFailureUnauthenticated,
    CloudSyncFailureKind.forbidden => l10n.cloudSyncFailureForbidden,
    CloudSyncFailureKind.notFound => l10n.cloudSyncFailureNotFound,
    CloudSyncFailureKind.conflict => l10n.cloudSyncFailureConflict,
    CloudSyncFailureKind.validation => l10n.cloudSyncFailureValidation,
    CloudSyncFailureKind.rateLimited => l10n.cloudSyncFailureRateLimited,
    CloudSyncFailureKind.server => l10n.cloudSyncFailureServer,
    CloudSyncFailureKind.network => l10n.cloudSyncFailureNetwork,
    CloudSyncFailureKind.timeout => l10n.cloudSyncFailureTimeout,
    CloudSyncFailureKind.cancelled => l10n.cloudSyncFailureCancelled,
    CloudSyncFailureKind.invalidResponse =>
      l10n.cloudSyncFailureInvalidResponse,
    CloudSyncFailureKind.unknown => l10n.cloudSyncFailureUnknown,
  };
}

String cloudSyncPlatformText(
  AppLocalizations l10n,
  CloudSyncPlatform platform,
) {
  return switch (platform) {
    CloudSyncPlatform.android => l10n.cloudSyncPlatformAndroid,
    CloudSyncPlatform.ios => l10n.cloudSyncPlatformIos,
    CloudSyncPlatform.macos => l10n.cloudSyncPlatformMacos,
    CloudSyncPlatform.windows => l10n.cloudSyncPlatformWindows,
    CloudSyncPlatform.linux => l10n.cloudSyncPlatformLinux,
  };
}

String _currentPlatformLabel(AppLocalizations l10n) {
  if (kIsWeb) return l10n.cloudSyncPlatformUnknown;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => l10n.cloudSyncPlatformAndroid,
    TargetPlatform.iOS => l10n.cloudSyncPlatformIos,
    TargetPlatform.macOS => l10n.cloudSyncPlatformMacos,
    TargetPlatform.windows => l10n.cloudSyncPlatformWindows,
    TargetPlatform.linux => l10n.cloudSyncPlatformLinux,
    TargetPlatform.fuchsia => l10n.cloudSyncPlatformUnknown,
  };
}

String _formatDateTime(BuildContext context, DateTime? value) {
  if (value == null) return AppLocalizations.of(context)!.cloudSyncNever;
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatMediumDate(local);
  final time = TimeOfDay.fromDateTime(local).format(context);
  return '$date $time';
}
