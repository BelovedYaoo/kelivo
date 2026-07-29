import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/cloud_sync_provider.dart';
import '../../../core/services/sync/e2ee_account_authenticator.dart';
import '../../../core/services/sync/cloud_sync_types.dart';
import '../../../core/services/sync/e2ee_first_device_recovery_bootstrap.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../scan/pages/qr_scan_page.dart';
import 'mobile_recovery_media_export_page.dart';

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

enum _CloudSyncAuthenticationMode { signIn, register }

class _CloudSyncSettingsContentState extends State<CloudSyncSettingsContent> {
  final TextEditingController _loginNameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _recoveryPassphraseController =
      TextEditingController();
  final TextEditingController _recoveryPassphraseConfirmController =
      TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();

  _CloudSyncAuthenticationMode _authenticationMode =
      _CloudSyncAuthenticationMode.signIn;
  bool _submitting = false;
  bool _deviceNameInitialized = false;
  String? _requestedDeviceScope;
  CloudSyncProvider? _provider;
  QrImage? _pendingPairingQrImage;
  int? _renderedPairingGeneration;
  bool _pairingQrUnavailable = false;
  bool _cancellingPairing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<CloudSyncProvider>();
    if (_deviceNameInitialized) return;
    final l10n = AppLocalizations.of(context)!;
    _deviceNameController.text = l10n.cloudSyncDefaultDeviceName(
      _currentPlatformLabel(l10n),
    );
    _deviceNameInitialized = true;
  }

  @override
  void dispose() {
    final provider = _provider;
    if (provider?.pendingDeviceApproval != null) {
      unawaited(provider!.cancelPendingDevicePairing());
    }
    _pendingPairingQrImage = null;
    _loginNameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _recoveryPassphraseController.dispose();
    _recoveryPassphraseConfirmController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CloudSyncProvider>();
    _syncPendingPairingQr(provider);
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
          if (provider.pendingDeviceApproval case final approval?)
            _buildPendingPairingSection(context, provider, approval)
          else
            _buildAuthenticationSection(context, provider)
        else ...[
          _buildAccountSection(context, provider, session),
          const SizedBox(height: 14),
          _NoticeCard(
            message: AppLocalizations.of(
              context,
            )!.cloudSyncContentLocalOnlyNotice,
          ),
          const SizedBox(height: 14),
          _buildDevicesSection(context, provider),
        ],
      ],
    );
  }

  void _syncPendingPairingQr(CloudSyncProvider provider) {
    if (provider.pendingDeviceApproval == null) {
      _pendingPairingQrImage = null;
      _renderedPairingGeneration = null;
      _pairingQrUnavailable = false;
      return;
    }
    final generation = provider.pendingDevicePairingGeneration;
    if (_renderedPairingGeneration == generation) return;
    _renderedPairingGeneration = generation;
    _pendingPairingQrImage = null;
    _pairingQrUnavailable = false;
    final frame = provider.takePendingDevicePairingQrFrame();
    if (frame == null) {
      _pairingQrUnavailable = true;
      return;
    }
    try {
      _pendingPairingQrImage = QrImage(
        QrCode.fromUint8List(
          data: frame,
          errorCorrectLevel: QrErrorCorrectLevel.L,
        ),
      );
    } catch (error, stackTrace) {
      _pairingQrUnavailable = true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Kelivo.CloudSync',
          context: ErrorDescription('生成设备配对二维码时'),
        ),
      );
    } finally {
      frame.fillRange(0, frame.length, 0);
    }
  }

  Widget _buildPendingPairingSection(
    BuildContext context,
    CloudSyncProvider provider,
    E2eeAccountLoginApprovalRequired approval,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final qrImage = _pendingPairingQrImage;
    final expiresAt = provider.pendingDevicePairingExpiresAt;
    return _Section(
      title: l10n.cloudSyncPairingSection,
      children: [
        _InfoRow(
          label: l10n.cloudSyncDeviceName,
          value: approval.device.name,
          detail: cloudSyncPlatformText(l10n, approval.device.platform),
        ),
        const _SectionDivider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (qrImage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.white,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: PrettyQrView(
                        qrImage: qrImage,
                        decoration: const PrettyQrDecoration(
                          quietZone: PrettyQrQuietZone.modules(4),
                        ),
                      ),
                    ),
                  ),
                )
              else if (_pairingQrUnavailable)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Text(
                    l10n.cloudSyncPairingQrUnavailable,
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(l10n.cloudSyncPairingWaiting)),
                ],
              ),
              if (expiresAt != null) ...[
                const SizedBox(height: 5),
                Text(
                  l10n.cloudSyncPairingExpiresAt(
                    _formatDateTime(context, expiresAt),
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: IosTileButton(
                  label: l10n.cloudSyncCancel,
                  icon: Lucide.X,
                  enabled: !_cancellingPairing,
                  foregroundColor: Theme.of(context).colorScheme.error,
                  borderColor: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.35),
                  onTap: () => unawaited(_cancelPendingPairing()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthenticationSection(
    BuildContext context,
    CloudSyncProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final registering = _registrationSelected;
    final busy =
        _submitting ||
        provider.status == CloudSyncProviderStatus.initializing ||
        provider.status == CloudSyncProviderStatus.signingIn ||
        provider.status == CloudSyncProviderStatus.awaitingDeviceApproval ||
        provider.status == CloudSyncProviderStatus.signingOut ||
        provider.status == CloudSyncProviderStatus.workspaceChangePending;
    return _Section(
      title: registering
          ? l10n.cloudSyncRegisterSection
          : l10n.cloudSyncSignInSection,
      children: [
        if (_supportsRegistration) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: IosTileButton(
                    key: const ValueKey<String>('cloud-sync-sign-in-mode'),
                    label: l10n.cloudSyncSignIn,
                    icon: Lucide.User,
                    enabled: !busy,
                    backgroundColor:
                        _authenticationMode ==
                            _CloudSyncAuthenticationMode.signIn
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    onTap: () => _selectAuthenticationMode(
                      _CloudSyncAuthenticationMode.signIn,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: IosTileButton(
                    key: const ValueKey<String>('cloud-sync-register-mode'),
                    label: l10n.cloudSyncRegister,
                    icon: Lucide.Plus,
                    enabled: !busy,
                    backgroundColor:
                        _authenticationMode ==
                            _CloudSyncAuthenticationMode.register
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    onTap: () => _selectAuthenticationMode(
                      _CloudSyncAuthenticationMode.register,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _SectionDivider(),
        ],
        IosFormTextField(
          key: const ValueKey<String>('cloud-sync-login-name-field'),
          label: l10n.cloudSyncLoginName,
          controller: _loginNameController,
          inlineLabel: widget.desktop,
          textInputAction: TextInputAction.next,
          enabled: !busy,
          autocorrect: false,
          enableSuggestions: false,
        ),
        if (registering) ...[
          const _SectionDivider(),
          IosFormTextField(
            key: const ValueKey<String>('cloud-sync-display-name-field'),
            label: l10n.cloudSyncDisplayName,
            controller: _displayNameController,
            inlineLabel: widget.desktop,
            textInputAction: TextInputAction.next,
            enabled: !busy,
          ),
        ],
        const _SectionDivider(),
        IosFormTextField(
          key: const ValueKey<String>('cloud-sync-password-field'),
          label: l10n.cloudSyncPassword,
          controller: _passwordController,
          inlineLabel: widget.desktop,
          textInputAction: TextInputAction.next,
          enabled: !busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
        ),
        if (registering) ...[
          const _SectionDivider(),
          IosFormTextField(
            key: const ValueKey<String>('cloud-sync-recovery-passphrase-field'),
            label: l10n.cloudSyncRecoveryPassphrase,
            controller: _recoveryPassphraseController,
            inlineLabel: widget.desktop,
            textInputAction: TextInputAction.next,
            enabled: !busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
          ),
          const _SectionDivider(),
          IosFormTextField(
            key: const ValueKey<String>(
              'cloud-sync-recovery-passphrase-confirm-field',
            ),
            label: l10n.cloudSyncRecoveryPassphraseConfirm,
            controller: _recoveryPassphraseConfirmController,
            inlineLabel: widget.desktop,
            textInputAction: TextInputAction.next,
            enabled: !busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text(
              l10n.cloudSyncRecoveryPassphraseDescription,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
        const _SectionDivider(),
        IosFormTextField(
          key: const ValueKey<String>('cloud-sync-device-name-field'),
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
              key: const ValueKey<String>('cloud-sync-authentication-submit'),
              label:
                  _submitting ||
                      provider.status == CloudSyncProviderStatus.signingIn
                  ? registering
                        ? l10n.cloudSyncRegistering
                        : l10n.cloudSyncSigningIn
                  : registering
                  ? l10n.cloudSyncRegister
                  : l10n.cloudSyncSignIn,
              icon: registering ? Lucide.Plus : Lucide.User,
              enabled: !busy,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.primary,
              onTap: () => unawaited(registering ? _register() : _signIn()),
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
        status == CloudSyncProviderStatus.workspaceChangePending;
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
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
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
            if (_supportsPairingApproval)
              IosIconButton(
                icon: Lucide.ScanLine,
                semanticLabel: l10n.cloudSyncApproveDevice,
                enabled: !provider.devicePairingApprovalInProgress,
                onTap: () => unawaited(_scanAndApproveDevicePairing()),
              ),
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
    if (_submitting) return;
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

    setState(() => _submitting = true);
    final provider = context.read<CloudSyncProvider>();
    late final bool success;
    try {
      success = await provider.login(
        loginName: loginName,
        password: password,
        deviceName: deviceName,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    if (provider.signedIn) {
      _passwordController.clear();
    }
    if (success) {
      _passwordController.clear();
      return;
    }
    if (provider.pendingDeviceApproval != null) {
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

  Future<void> _register() async {
    if (_submitting || !_supportsRegistration) return;
    final l10n = AppLocalizations.of(context)!;
    final loginName = _loginNameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;
    var recoveryPassphrase = _recoveryPassphraseController.text;
    var recoveryPassphraseConfirm = _recoveryPassphraseConfirmController.text;
    final deviceName = _deviceNameController.text.trim();
    if (loginName.isEmpty ||
        displayName.isEmpty ||
        password.isEmpty ||
        recoveryPassphrase.isEmpty ||
        recoveryPassphraseConfirm.isEmpty ||
        deviceName.isEmpty) {
      showAppSnackBar(
        context,
        message: l10n.cloudSyncRegistrationRequiredFields,
        type: NotificationType.warning,
      );
      return;
    }
    if (recoveryPassphrase != recoveryPassphraseConfirm) {
      showAppSnackBar(
        context,
        message: l10n.cloudSyncRecoveryPassphraseMismatch,
        type: NotificationType.warning,
      );
      return;
    }
    final recoveryPassphraseError = switch (validateE2eeRecoveryPassphraseText(
      recoveryPassphrase,
    )) {
      E2eeRecoveryPassphraseValidation.valid => null,
      E2eeRecoveryPassphraseValidation.tooShort =>
        l10n.cloudSyncRecoveryPassphraseTooShort,
      E2eeRecoveryPassphraseValidation.tooLong =>
        l10n.cloudSyncRecoveryPassphraseTooLong,
      E2eeRecoveryPassphraseValidation.invalidUtf8 =>
        l10n.cloudSyncRecoveryPassphraseInvalid,
    };
    if (recoveryPassphraseError != null) {
      showAppSnackBar(
        context,
        message: recoveryPassphraseError,
        type: NotificationType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    final provider = context.read<CloudSyncProvider>();
    E2eeFirstDeviceRecoveryBootstrapPreparer? bootstrapPreparer;
    MobileRecoveryMediaExportResult? exportResult;
    late final bool success;
    try {
      final recoveryPassphraseBytes = Uint8List.fromList(
        utf8.encode(recoveryPassphrase),
      );
      try {
        bootstrapPreparer = E2eeFirstDeviceRecoveryBootstrapPreparer(
          recoveryPassphrase: recoveryPassphraseBytes,
          serviceOrigin: e2eeCanonicalRecoveryServiceOrigin,
          encryptedMediaExporter: (encryptedMedia) async {
            try {
              if (!mounted) {
                exportResult = MobileRecoveryMediaExportResult.cancelled;
                return false;
              }
              exportResult =
                  await Navigator.of(
                    context,
                  ).push<MobileRecoveryMediaExportResult>(
                    MaterialPageRoute<MobileRecoveryMediaExportResult>(
                      builder: (_) => MobileRecoveryMediaExportPage(
                        encryptedMedia: encryptedMedia,
                      ),
                    ),
                  ) ??
                  MobileRecoveryMediaExportResult.cancelled;
              return exportResult == MobileRecoveryMediaExportResult.confirmed;
            } finally {
              encryptedMedia.fillRange(0, encryptedMedia.length, 0);
            }
          },
        );
      } finally {
        recoveryPassphraseBytes.fillRange(0, recoveryPassphraseBytes.length, 0);
        // 尽早解除 async 状态机对不可主动清零 String 的引用。
        recoveryPassphrase = '';
        recoveryPassphraseConfirm = '';
        _recoveryPassphraseController.clear();
        _recoveryPassphraseConfirmController.clear();
      }
      success = await provider.register(
        loginName: loginName,
        displayName: displayName,
        password: password,
        deviceName: deviceName,
        firstDeviceBootstrapPreparer: bootstrapPreparer,
      );
    } finally {
      bootstrapPreparer?.close();
      _recoveryPassphraseController.clear();
      _recoveryPassphraseConfirmController.clear();
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    if (success || provider.signedIn) {
      _passwordController.clear();
      return;
    }
    if (exportResult == MobileRecoveryMediaExportResult.cancelled) {
      provider.clearError();
      return;
    }
    if (exportResult == MobileRecoveryMediaExportResult.fileSaveFailed) {
      provider.clearError();
      showAppSnackBar(
        context,
        message: l10n.cloudSyncRecoveryMediaSaveFailed,
        type: NotificationType.error,
      );
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

  bool get _supportsRegistration {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _registrationSelected {
    return _supportsRegistration &&
        _authenticationMode == _CloudSyncAuthenticationMode.register;
  }

  void _selectAuthenticationMode(_CloudSyncAuthenticationMode mode) {
    if (_submitting || mode == _authenticationMode) return;
    context.read<CloudSyncProvider>().clearError();
    if (mode != _CloudSyncAuthenticationMode.register) {
      _recoveryPassphraseController.clear();
      _recoveryPassphraseConfirmController.clear();
    }
    setState(() => _authenticationMode = mode);
  }

  bool get _supportsPairingApproval {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _cancelPendingPairing() async {
    if (_cancellingPairing) return;
    setState(() => _cancellingPairing = true);
    final provider = context.read<CloudSyncProvider>();
    final success = await provider.cancelPendingDevicePairing();
    if (!mounted) return;
    setState(() => _cancellingPairing = false);
    if (success || provider.pendingDeviceApproval == null) return;
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

  Future<void> _scanAndApproveDevicePairing() async {
    final frame = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(builder: (_) => const BinaryQrScanPage()),
    );
    if (frame == null) return;
    if (!mounted) {
      frame.fillRange(0, frame.length, 0);
      return;
    }
    final provider = context.read<CloudSyncProvider>();
    final success = await provider.approveDevicePairing(frame);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      message: success
          ? l10n.cloudSyncApproveDeviceSuccess
          : cloudSyncFailureText(
              l10n,
              provider.deviceError ??
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

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.message});

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
          Icon(Lucide.BadgeInfo, size: 19, color: cs.tertiary),
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
