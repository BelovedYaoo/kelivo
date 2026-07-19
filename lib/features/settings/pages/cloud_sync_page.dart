import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/cloud_sync_provider.dart';
import '../../../core/services/sync/cloud_sync_conflict_presentation.dart';
import '../../../core/services/sync/cloud_sync_conflict_resolver.dart';
import '../../../core/services/sync/cloud_sync_types.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/custom_bottom_sheet.dart';
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
  final TextEditingController _loginNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();

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
    _loginNameController.dispose();
    _passwordController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CloudSyncProvider>();
    final session = provider.session;
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
          _buildConflictsSection(context, provider),
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
        provider.status == CloudSyncProviderStatus.signingIn ||
        provider.status == CloudSyncProviderStatus.signingOut ||
        provider.status == CloudSyncProviderStatus.workspaceChangePending;
    return _Section(
      title: l10n.cloudSyncSignInSection,
      children: [
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
        status == CloudSyncProviderStatus.signingIn ||
        status == CloudSyncProviderStatus.workspaceChangePending ||
        provider.conflictsLoading ||
        provider.resolvingConflictId != null;
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

  Widget _buildConflictsSection(
    BuildContext context,
    CloudSyncProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final busy =
        provider.conflictsLoading ||
        provider.resolvingConflictId != null ||
        provider.status == CloudSyncProviderStatus.syncing ||
        provider.status == CloudSyncProviderStatus.signingOut;
    final failureReason = provider.conflictResolutionFailure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SectionHeader(l10n.cloudSyncConflictsSection)),
            IosIconButton(
              icon: Lucide.RefreshCw,
              semanticLabel: l10n.cloudSyncRefreshConflicts,
              enabled: !busy && !provider.paused,
              onTap: () => unawaited(provider.refreshConflicts()),
            ),
          ],
        ),
        if (provider.conflictError case final error?) ...[
          const SizedBox(height: 6),
          _ErrorCard(
            title: l10n.cloudSyncConflictErrorTitle,
            message: cloudSyncFailureText(l10n, error),
          ),
          const SizedBox(height: 10),
        ] else if (failureReason != null) ...[
          const SizedBox(height: 6),
          _ErrorCard(
            title: l10n.cloudSyncConflictErrorTitle,
            message: cloudSyncConflictResolutionFailureText(
              l10n,
              failureReason,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (provider.conflictListTruncated) ...[
          const SizedBox(height: 6),
          _ConflictNoticeCard(message: l10n.cloudSyncConflictsTruncated),
          const SizedBox(height: 10),
        ],
        _SectionCard(
          children: [
            if (provider.conflictsLoading && provider.conflicts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.conflicts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  l10n.cloudSyncNoConflicts,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              )
            else
              for (
                int index = 0;
                index < provider.conflicts.length;
                index++
              ) ...[
                _ConflictRow(
                  descriptor: describeCloudSyncConflict(
                    provider.conflicts[index],
                  ),
                  enabled: !busy && !provider.paused,
                  resolving:
                      provider.resolvingConflictId ==
                      provider.conflicts[index].conflictId,
                  onTap: () => _showConflictResolutionSheet(
                    provider.conflicts[index],
                    provider.conflictListTruncated,
                  ),
                ),
                if (index != provider.conflicts.length - 1)
                  const _SectionDivider(),
              ],
          ],
        ),
      ],
    );
  }

  Future<void> _showConflictResolutionSheet(
    CloudSyncConflict conflict,
    bool conflictListTruncated,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final descriptor = describeCloudSyncConflict(conflict);
    return showCustomBottomSheet<void>(
      context: context,
      title: l10n.cloudSyncConflictResolveTitle,
      count: descriptor.fields.length,
      closeSemanticLabel: l10n.cloudSyncConflictClose,
      partialHeightFactor: 0.72,
      expandedHeightFactor: 0.94,
      builder: (sheetContext, scrollController) {
        return _CloudSyncConflictResolutionSheet(
          conflict: conflict,
          descriptor: descriptor,
          conflictListTruncated: conflictListTruncated,
          scrollController: scrollController,
        );
      },
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
    final loginName = _loginNameController.text.trim();
    final password = _passwordController.text;
    final deviceName = _deviceNameController.text.trim();
    if (loginName.isEmpty || password.isEmpty || deviceName.isEmpty) {
      showAppSnackBar(
        context,
        message: l10n.cloudSyncRequiredFields,
        type: NotificationType.warning,
      );
      return;
    }

    final provider = context.read<CloudSyncProvider>();
    final success = await provider.login(
      loginName: loginName,
      password: password,
      deviceName: deviceName,
    );
    if (!mounted) return;
    final authenticatedButIncomplete =
        provider.signedIn && provider.lastError == null;
    final incompleteMessage = switch (provider.status) {
      CloudSyncProviderStatus.pendingSync => l10n.cloudSyncSyncPending,
      CloudSyncProviderStatus.syncBlocked => l10n.cloudSyncSyncBlocked,
      _ => l10n.cloudSyncSyncNeedsAttention,
    };
    if (provider.signedIn) {
      _passwordController.clear();
    }
    if (success) {
      _passwordController.clear();
      return;
    }
    showAppSnackBar(
      context,
      message: authenticatedButIncomplete
          ? incompleteMessage
          : cloudSyncFailureText(
              l10n,
              provider.lastError ??
                  const CloudSyncException(
                    kind: CloudSyncFailureKind.unknown,
                    retryable: false,
                  ),
            ),
      type: authenticatedButIncomplete
          ? NotificationType.warning
          : NotificationType.error,
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
    final incomplete =
        !success &&
        provider.lastError == null &&
        (provider.status == CloudSyncProviderStatus.pendingSync ||
            provider.status == CloudSyncProviderStatus.syncBlocked ||
            provider.status == CloudSyncProviderStatus.needsAttention);
    final incompleteMessage = switch (provider.status) {
      CloudSyncProviderStatus.pendingSync => l10n.cloudSyncSyncPending,
      CloudSyncProviderStatus.syncBlocked => l10n.cloudSyncSyncBlocked,
      _ => l10n.cloudSyncSyncNeedsAttention,
    };
    showAppSnackBar(
      context,
      message: success
          ? l10n.cloudSyncSyncCompleted
          : incomplete
          ? incompleteMessage
          : cloudSyncFailureText(
              l10n,
              provider.lastError ??
                  const CloudSyncException(
                    kind: CloudSyncFailureKind.unknown,
                    retryable: false,
                  ),
            ),
      type: success
          ? NotificationType.success
          : incomplete
          ? NotificationType.warning
          : NotificationType.error,
    );
  }

  Future<void> _revokeDevice(CloudSyncDeviceSession device) async {
    final confirmed = await _showRevokeDialog(device);
    if (confirmed != true || !mounted) return;
    final provider = context.read<CloudSyncProvider>();
    final success = await provider.revokeDevice(device.id);
    if (!mounted) return;
    if (success) {
      return;
    }
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
    final confirmed = await _showLogoutDialog();
    if (confirmed != true || !mounted) return;
    final provider = context.read<CloudSyncProvider>();
    final success = await provider.logout();
    if (!mounted) return;
    if (success) {
      return;
    }
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

  Future<bool?> _showLogoutDialog() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
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
            onTap: () => Navigator.of(dialogContext).pop(true),
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

class _ConflictRow extends StatelessWidget {
  const _ConflictRow({
    required this.descriptor,
    required this.enabled,
    required this.resolving,
    required this.onTap,
  });

  final CloudSyncConflictPresentationDescriptor descriptor;
  final bool enabled;
  final bool resolving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final previewFields = descriptor.fields.take(2).toList(growable: false);
    final entityText = cloudSyncConflictEntityText(
      l10n,
      descriptor.entityCategory,
    );
    final fieldCountText = l10n.cloudSyncConflictFieldCount(
      descriptor.fields.length,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$entityText. $fieldCountText',
      excludeSemantics: true,
      child: IosCardPress(
        onTap: enabled ? onTap : null,
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Lucide.MessageCircleWarning,
                size: 19,
                color: cs.tertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entityText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fieldCountText,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.58),
                    ),
                  ),
                  for (final field in previewFields) ...[
                    const SizedBox(height: 5),
                    Text(
                      cloudSyncConflictFieldText(l10n, field.category),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: AppFontWeights.medium,
                        color: cs.onSurface.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l10n.cloudSyncConflictValueComparison(
                        cloudSyncConflictValueText(l10n, field.current),
                        cloudSyncConflictValueText(l10n, field.desired),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: cs.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: resolving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Lucide.ChevronRight,
                      size: 18,
                      color: cs.onSurface.withValues(
                        alpha: enabled ? 0.42 : 0.2,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictNoticeCard extends StatelessWidget {
  const _ConflictNoticeCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Lucide.MessageCircleWarning, size: 19, color: cs.tertiary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: cs.onTertiaryContainer.withValues(alpha: 0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudSyncConflictResolutionSheet extends StatefulWidget {
  const _CloudSyncConflictResolutionSheet({
    required this.conflict,
    required this.descriptor,
    required this.conflictListTruncated,
    required this.scrollController,
  });

  final CloudSyncConflict conflict;
  final CloudSyncConflictPresentationDescriptor descriptor;
  final bool conflictListTruncated;
  final ScrollController scrollController;

  @override
  State<_CloudSyncConflictResolutionSheet> createState() =>
      _CloudSyncConflictResolutionSheetState();
}

class _CloudSyncConflictResolutionSheetState
    extends State<_CloudSyncConflictResolutionSheet> {
  final Set<int> _selectedLocalFieldIndexes = <int>{};
  bool _resolving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final allCloud = _selectedLocalFieldIndexes.isEmpty;
    final allLocal =
        _selectedLocalFieldIndexes.length == widget.descriptor.fields.length;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          l10n.cloudSyncConflictResolveDescription(
            cloudSyncConflictEntityText(l10n, widget.descriptor.entityCategory),
          ),
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: cs.onSurface.withValues(alpha: 0.72),
          ),
        ),
        if (widget.conflictListTruncated) ...[
          const SizedBox(height: 12),
          _ConflictNoticeCard(
            message: l10n.cloudSyncConflictTruncatedLocalBlocked,
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: IosTileButton(
                label: l10n.cloudSyncConflictUseAllCloud,
                icon: allCloud ? Lucide.Check : Lucide.Database,
                enabled: !_resolving,
                backgroundColor: allCloud ? cs.primary : null,
                foregroundColor: allCloud ? cs.primary : null,
                onTap: () {
                  setState(() {
                    _selectedLocalFieldIndexes.clear();
                    _errorMessage = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: IosTileButton(
                label: l10n.cloudSyncConflictUseAllLocal,
                icon: allLocal ? Lucide.Check : Lucide.Monitor,
                enabled: !_resolving && !widget.conflictListTruncated,
                backgroundColor: allLocal ? cs.primary : null,
                foregroundColor: allLocal ? cs.primary : null,
                onTap: () {
                  setState(() {
                    _selectedLocalFieldIndexes
                      ..clear()
                      ..addAll(
                        List<int>.generate(
                          widget.descriptor.fields.length,
                          (index) => index,
                        ),
                      );
                    _errorMessage = null;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (
          int index = 0;
          index < widget.descriptor.fields.length;
          index++
        ) ...[
          _ConflictFieldChoiceCard(
            descriptor: widget.descriptor.fields[index],
            useLocal: _selectedLocalFieldIndexes.contains(index),
            enabled: !_resolving,
            localEnabled: !widget.conflictListTruncated,
            onUseCloud: () {
              setState(() {
                _selectedLocalFieldIndexes.remove(index);
                _errorMessage = null;
              });
            },
            onUseLocal: () {
              setState(() {
                _selectedLocalFieldIndexes.add(index);
                _errorMessage = null;
              });
            },
          ),
          if (index != widget.descriptor.fields.length - 1)
            const SizedBox(height: 10),
        ],
        if (_errorMessage case final error?) ...[
          const SizedBox(height: 12),
          _ErrorCard(title: l10n.cloudSyncConflictErrorTitle, message: error),
        ],
        const SizedBox(height: 16),
        IosTileButton(
          label: _resolving
              ? l10n.cloudSyncConflictResolving
              : l10n.cloudSyncConflictConfirm,
          icon: Lucide.Check,
          enabled: !_resolving,
          backgroundColor: cs.primary,
          foregroundColor: cs.primary,
          onTap: () => unawaited(_resolve()),
        ),
      ],
    );
  }

  Future<void> _resolve() async {
    if (_resolving) return;
    setState(() {
      _resolving = true;
      _errorMessage = null;
    });

    final localPaths = <String>{
      for (final index in _selectedLocalFieldIndexes)
        widget.conflict.fields[index].path,
    };
    final provider = context.read<CloudSyncProvider>();
    final success = await provider.resolveConflict(widget.conflict, localPaths);
    if (!mounted) return;
    if (success) {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.cloudSyncConflictResolved,
        type: NotificationType.success,
      );
      Navigator.of(context).maybePop();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final failureReason = provider.conflictResolutionFailure;
    final conflictError = provider.conflictError;
    setState(() {
      _resolving = false;
      _errorMessage = failureReason != null
          ? cloudSyncConflictResolutionFailureText(l10n, failureReason)
          : conflictError != null
          ? cloudSyncFailureText(l10n, conflictError)
          : l10n.cloudSyncConflictResolveFailed;
    });
  }
}

class _ConflictFieldChoiceCard extends StatelessWidget {
  const _ConflictFieldChoiceCard({
    required this.descriptor,
    required this.useLocal,
    required this.enabled,
    required this.localEnabled,
    required this.onUseCloud,
    required this.onUseLocal,
  });

  final CloudSyncConflictFieldDescriptor descriptor;
  final bool useLocal;
  final bool enabled;
  final bool localEnabled;
  final VoidCallback onUseCloud;
  final VoidCallback onUseLocal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cloudSyncConflictFieldText(l10n, descriptor.category),
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ConflictValuePanel(
                  label: l10n.cloudSyncConflictCloudValue,
                  value: cloudSyncConflictValueText(l10n, descriptor.current),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConflictValuePanel(
                  label: l10n.cloudSyncConflictLocalValue,
                  value: cloudSyncConflictValueText(l10n, descriptor.desired),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: IosTileButton(
                  label: l10n.cloudSyncConflictUseCloud,
                  icon: useLocal ? Lucide.Database : Lucide.Check,
                  enabled: enabled,
                  backgroundColor: useLocal ? null : cs.primary,
                  foregroundColor: useLocal ? null : cs.primary,
                  onTap: onUseCloud,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: IosTileButton(
                  label: l10n.cloudSyncConflictUseLocal,
                  icon: useLocal ? Lucide.Check : Lucide.Monitor,
                  enabled: enabled && localEnabled,
                  backgroundColor: useLocal ? cs.primary : null,
                  foregroundColor: useLocal ? cs.primary : null,
                  onTap: onUseLocal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConflictValuePanel extends StatelessWidget {
  const _ConflictValuePanel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.52),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.3, color: cs.onSurface),
          ),
        ],
      ),
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
    CloudSyncProviderStatus.workspaceChangePending =>
      l10n.cloudSyncStatusWorkspaceChangePending,
    CloudSyncProviderStatus.idle => l10n.cloudSyncStatusIdle,
    CloudSyncProviderStatus.syncing => l10n.cloudSyncStatusSyncing,
    CloudSyncProviderStatus.pendingSync => l10n.cloudSyncStatusPendingSync,
    CloudSyncProviderStatus.syncBlocked => l10n.cloudSyncStatusBlocked,
    CloudSyncProviderStatus.needsAttention =>
      l10n.cloudSyncStatusNeedsAttention,
    CloudSyncProviderStatus.paused => l10n.cloudSyncStatusPaused,
    CloudSyncProviderStatus.error => l10n.cloudSyncStatusError,
  };
}

String cloudSyncConflictEntityText(
  AppLocalizations l10n,
  CloudSyncConflictEntityCategory category,
) {
  return switch (category) {
    CloudSyncConflictEntityCategory.conversation =>
      l10n.cloudSyncConflictEntityConversation,
    CloudSyncConflictEntityCategory.turn => l10n.cloudSyncConflictEntityTurn,
    CloudSyncConflictEntityCategory.message =>
      l10n.cloudSyncConflictEntityMessage,
    CloudSyncConflictEntityCategory.messageSelection =>
      l10n.cloudSyncConflictEntityMessageSelection,
    CloudSyncConflictEntityCategory.toolEvent =>
      l10n.cloudSyncConflictEntityToolEvent,
    CloudSyncConflictEntityCategory.thoughtSignature =>
      l10n.cloudSyncConflictEntityThoughtSignature,
    CloudSyncConflictEntityCategory.provider =>
      l10n.cloudSyncConflictEntityProvider,
    CloudSyncConflictEntityCategory.assistant =>
      l10n.cloudSyncConflictEntityAssistant,
    CloudSyncConflictEntityCategory.memory =>
      l10n.cloudSyncConflictEntityMemory,
    CloudSyncConflictEntityCategory.worldBook =>
      l10n.cloudSyncConflictEntityWorldBook,
    CloudSyncConflictEntityCategory.quickPhrase =>
      l10n.cloudSyncConflictEntityQuickPhrase,
    CloudSyncConflictEntityCategory.searchService =>
      l10n.cloudSyncConflictEntitySearchService,
    CloudSyncConflictEntityCategory.networkTts =>
      l10n.cloudSyncConflictEntityNetworkTts,
    CloudSyncConflictEntityCategory.mcpServer =>
      l10n.cloudSyncConflictEntityMcpServer,
    CloudSyncConflictEntityCategory.instructionInjection =>
      l10n.cloudSyncConflictEntityInstructionInjection,
    CloudSyncConflictEntityCategory.userPreference =>
      l10n.cloudSyncConflictEntityUserPreference,
  };
}

String cloudSyncConflictFieldText(
  AppLocalizations l10n,
  CloudSyncConflictFieldCategory category,
) {
  return switch (category) {
    CloudSyncConflictFieldCategory.title => l10n.cloudSyncConflictFieldTitle,
    CloudSyncConflictFieldCategory.content =>
      l10n.cloudSyncConflictFieldContent,
    CloudSyncConflictFieldCategory.summary =>
      l10n.cloudSyncConflictFieldSummary,
    CloudSyncConflictFieldCategory.name => l10n.cloudSyncConflictFieldName,
    CloudSyncConflictFieldCategory.status => l10n.cloudSyncConflictFieldStatus,
    CloudSyncConflictFieldCategory.time => l10n.cloudSyncConflictFieldTime,
    CloudSyncConflictFieldCategory.settings =>
      l10n.cloudSyncConflictFieldSettings,
    CloudSyncConflictFieldCategory.security =>
      l10n.cloudSyncConflictFieldSecurity,
    CloudSyncConflictFieldCategory.reference =>
      l10n.cloudSyncConflictFieldReference,
    CloudSyncConflictFieldCategory.attachments =>
      l10n.cloudSyncConflictFieldAttachments,
    CloudSyncConflictFieldCategory.selection =>
      l10n.cloudSyncConflictFieldSelection,
    CloudSyncConflictFieldCategory.other => l10n.cloudSyncConflictFieldOther,
  };
}

String cloudSyncConflictValueText(
  AppLocalizations l10n,
  CloudSyncConflictValueDescriptor descriptor,
) {
  return switch (descriptor) {
    CloudSyncAbsentValueDescriptor() => l10n.cloudSyncConflictValueAbsent,
    CloudSyncNullValueDescriptor() => l10n.cloudSyncConflictValueEmpty,
    CloudSyncHiddenValueDescriptor(state: final state) => switch (state) {
      CloudSyncHiddenValueState.set => l10n.cloudSyncConflictValueSet,
      CloudSyncHiddenValueState.missing => l10n.cloudSyncConflictValueNotSet,
    },
    CloudSyncReferenceValueDescriptor() => l10n.cloudSyncConflictValueReference,
    CloudSyncItemCountValueDescriptor(itemCount: final itemCount) =>
      l10n.cloudSyncConflictValueItems(itemCount),
    CloudSyncBooleanValueDescriptor(value: final value) =>
      value
          ? l10n.cloudSyncConflictValueEnabled
          : l10n.cloudSyncConflictValueDisabled,
    CloudSyncNumberValueDescriptor(value: final value) =>
      l10n.cloudSyncConflictValueNumber(value),
    CloudSyncTextValueDescriptor(value: final value) =>
      value.trim().isEmpty ? l10n.cloudSyncConflictValueBlank : value,
  };
}

String cloudSyncConflictResolutionFailureText(
  AppLocalizations l10n,
  CloudSyncConflictResolutionFailureReason reason,
) {
  return switch (reason) {
    CloudSyncConflictResolutionFailureReason.conflictNotOpen ||
    CloudSyncConflictResolutionFailureReason.conflictIdentityChanged ||
    CloudSyncConflictResolutionFailureReason.conflictDetailsChanged ||
    CloudSyncConflictResolutionFailureReason.entityHasAnotherConflict =>
      l10n.cloudSyncConflictFailureChanged,
    CloudSyncConflictResolutionFailureReason.invalidLocalPath ||
    CloudSyncConflictResolutionFailureReason.unsupportedNestedPath ||
    CloudSyncConflictResolutionFailureReason.duplicateConflictPath =>
      l10n.cloudSyncConflictFailureSelection,
    CloudSyncConflictResolutionFailureReason.duplicateAdapterEntityType ||
    CloudSyncConflictResolutionFailureReason.unsupportedEntityType =>
      l10n.cloudSyncConflictFailureUnsupported,
    CloudSyncConflictResolutionFailureReason.incompleteConflictList =>
      l10n.cloudSyncConflictFailureIncomplete,
    CloudSyncConflictResolutionFailureReason.invalidShadow ||
    CloudSyncConflictResolutionFailureReason.entityHasOutbox =>
      l10n.cloudSyncConflictFailurePendingWrites,
    CloudSyncConflictResolutionFailureReason.verificationMismatch ||
    CloudSyncConflictResolutionFailureReason.invalidResolveResult =>
      l10n.cloudSyncConflictFailureVerification,
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
