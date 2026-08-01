import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/cloud_sync_provider.dart';
import '../../../core/services/sync/e2ee_account_recovery_runner.dart';
import '../../../core/services/sync/e2ee_first_device_recovery_bootstrap.dart';
import '../../../core/services/sync/e2ee_first_device_registration_commit_coordinator.dart';
import '../../../core/services/sync/sensitive_utf8.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../scan/pages/qr_scan_page.dart';
import 'cloud_sync_failure_text.dart';

typedef MobileAccountRecoveryQrScanner =
    Future<Uint8List?> Function(BuildContext context);
typedef MobileAccountRecoveryFilePicker = Future<Uint8List?> Function();

enum MobileAccountRecoveryMediaFailure { invalid, unreadable }

final class MobileAccountRecoveryMediaException implements Exception {
  const MobileAccountRecoveryMediaException(this.failure);

  final MobileAccountRecoveryMediaFailure failure;
}

Future<Uint8List?> scanMobileAccountRecoveryQr(BuildContext context) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute<Uint8List>(builder: (_) => const BinaryQrScanPage()),
  );
}

Future<Uint8List?> pickMobileAccountRecoveryFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const <String>['kelivo-recovery'],
    allowMultiple: false,
    withData: false,
    withReadStream: true,
  );
  if (result == null) return null;
  if (result.files.length != 1 ||
      result.files.single.size != e2eeEncryptedRecoveryMediaBytes) {
    throw const MobileAccountRecoveryMediaException(
      MobileAccountRecoveryMediaFailure.invalid,
    );
  }
  final stream = result.files.single.readStream;
  if (stream == null) {
    throw const MobileAccountRecoveryMediaException(
      MobileAccountRecoveryMediaFailure.unreadable,
    );
  }

  final media = Uint8List(e2eeEncryptedRecoveryMediaBytes);
  var offset = 0;
  try {
    await for (final chunk in stream) {
      if (offset + chunk.length > media.length) {
        throw const MobileAccountRecoveryMediaException(
          MobileAccountRecoveryMediaFailure.invalid,
        );
      }
      media.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    if (offset != media.length) {
      throw const MobileAccountRecoveryMediaException(
        MobileAccountRecoveryMediaFailure.invalid,
      );
    }
    return media;
  } catch (_) {
    media.fillRange(0, media.length, 0);
    rethrow;
  }
}

final class MobileAccountRecoveryPage extends StatefulWidget {
  const MobileAccountRecoveryPage({
    super.key,
    required this.initialDeviceName,
    this.initialLoginName = '',
    this.qrScanner = scanMobileAccountRecoveryQr,
    this.filePicker = pickMobileAccountRecoveryFile,
  });

  final String initialLoginName;
  final String initialDeviceName;
  final MobileAccountRecoveryQrScanner qrScanner;
  final MobileAccountRecoveryFilePicker filePicker;

  @override
  State<MobileAccountRecoveryPage> createState() =>
      _MobileAccountRecoveryPageState();
}

enum _RecoveryMediaSource { qr, file }

final class _MobileAccountRecoveryPageState
    extends State<MobileAccountRecoveryPage> {
  late final TextEditingController _loginNameController;
  late final TextEditingController _deviceNameController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _recoveryPassphraseController =
      TextEditingController();
  Uint8List? _encryptedRecoveryMedia;
  _RecoveryMediaSource? _mediaSource;
  bool _pickingMedia = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loginNameController = TextEditingController(text: widget.initialLoginName);
    _deviceNameController = TextEditingController(
      text: widget.initialDeviceName,
    );
  }

  @override
  void dispose() {
    _clearRecoveryMedia();
    _passwordController.clear();
    _recoveryPassphraseController.clear();
    _loginNameController.dispose();
    _deviceNameController.dispose();
    _passwordController.dispose();
    _recoveryPassphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<CloudSyncProvider>();
    final progress = provider.accountRecoveryProgress;
    final busy =
        _pickingMedia ||
        _submitting ||
        provider.status == CloudSyncProviderStatus.recoveringAccount;
    final progressText = _progressText(l10n, progress);
    final recoveryError = progress == E2eeAccountRecoveryProgress.failed
        ? provider.lastError
        : null;
    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          minSize: 44,
          semanticLabel: l10n.settingsPageBackButton,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.cloudSyncAccountRecoveryTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            IosFormTextField(
              key: const ValueKey<String>('mobile-account-recovery-login-name'),
              label: l10n.cloudSyncLoginName,
              controller: _loginNameController,
              enabled: !busy,
              textInputAction: TextInputAction.next,
            ),
            IosFormTextField(
              key: const ValueKey<String>('mobile-account-recovery-password'),
              label: l10n.cloudSyncPassword,
              controller: _passwordController,
              enabled: !busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
            ),
            IosFormTextField(
              key: const ValueKey<String>('mobile-account-recovery-passphrase'),
              label: l10n.cloudSyncRecoveryPassphrase,
              controller: _recoveryPassphraseController,
              enabled: !busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
            ),
            IosFormTextField(
              key: const ValueKey<String>(
                'mobile-account-recovery-device-name',
              ),
              label: l10n.cloudSyncDeviceName,
              controller: _deviceNameController,
              enabled: !busy,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.cloudSyncAccountRecoveryMediaSection,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: IosTileButton(
                    key: const ValueKey<String>(
                      'mobile-account-recovery-scan-qr',
                    ),
                    label: l10n.cloudSyncAccountRecoveryScanQr,
                    icon: Lucide.ScanLine,
                    enabled: !busy,
                    onTap: _scanQr,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: IosTileButton(
                    key: const ValueKey<String>(
                      'mobile-account-recovery-pick-file',
                    ),
                    label: l10n.cloudSyncAccountRecoveryPickFile,
                    icon: Lucide.FolderOpen,
                    enabled: !busy,
                    onTap: _pickFile,
                  ),
                ),
              ],
            ),
            if (_mediaSource case final source?) ...[
              const SizedBox(height: 12),
              _RecoveryStatusPanel(
                icon: Lucide.CheckCircle,
                message: source == _RecoveryMediaSource.qr
                    ? l10n.cloudSyncAccountRecoveryQrReady
                    : l10n.cloudSyncAccountRecoveryFileReady,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
            if (progressText != null) ...[
              const SizedBox(height: 12),
              _RecoveryStatusPanel(
                icon: progress == E2eeAccountRecoveryProgress.failed
                    ? Lucide.TriangleAlert
                    : progress == E2eeAccountRecoveryProgress.completed
                    ? Lucide.CheckCircle
                    : Lucide.RefreshCw,
                message: progressText,
                color: progress == E2eeAccountRecoveryProgress.failed
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                showProgress:
                    progress != E2eeAccountRecoveryProgress.failed &&
                    progress != E2eeAccountRecoveryProgress.completed,
              ),
            ],
            if (recoveryError != null) ...[
              const SizedBox(height: 8),
              Text(
                cloudSyncFailureText(l10n, recoveryError),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            IosTileButton(
              key: const ValueKey<String>('mobile-account-recovery-submit'),
              label: l10n.cloudSyncAccountRecoveryStart,
              icon: Lucide.Shield,
              enabled:
                  provider.accountRecoverySupported &&
                  _encryptedRecoveryMedia != null &&
                  !busy,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.primary,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanQr() async {
    if (_pickingMedia || _submitting) return;
    setState(() => _pickingMedia = true);
    Uint8List? media;
    try {
      media = await widget.qrScanner(context);
      if (media == null) return;
      if (!mounted) {
        media.fillRange(0, media.length, 0);
        return;
      }
      _adoptMedia(media, _RecoveryMediaSource.qr);
      media = null;
    } catch (error) {
      _reportMediaFailure(error);
    } finally {
      media?.fillRange(0, media.length, 0);
      if (mounted) setState(() => _pickingMedia = false);
    }
  }

  Future<void> _pickFile() async {
    if (_pickingMedia || _submitting) return;
    setState(() => _pickingMedia = true);
    Uint8List? media;
    try {
      media = await widget.filePicker();
      if (media == null) return;
      if (!mounted) {
        media.fillRange(0, media.length, 0);
        return;
      }
      _adoptMedia(media, _RecoveryMediaSource.file);
      media = null;
    } catch (error) {
      _reportMediaFailure(error);
    } finally {
      media?.fillRange(0, media.length, 0);
      if (mounted) setState(() => _pickingMedia = false);
    }
  }

  void _adoptMedia(Uint8List media, _RecoveryMediaSource source) {
    try {
      if (media.length != e2eeEncryptedRecoveryMediaBytes) {
        throw const MobileAccountRecoveryMediaException(
          MobileAccountRecoveryMediaFailure.invalid,
        );
      }
      final owned = Uint8List.fromList(media);
      _clearRecoveryMedia();
      setState(() {
        _encryptedRecoveryMedia = owned;
        _mediaSource = source;
      });
    } finally {
      media.fillRange(0, media.length, 0);
    }
  }

  void _clearRecoveryMedia() {
    final media = _encryptedRecoveryMedia;
    _encryptedRecoveryMedia = null;
    _mediaSource = null;
    media?.fillRange(0, media.length, 0);
  }

  void _reportMediaFailure(Object error) {
    if (!mounted) return;
    if (_encryptedRecoveryMedia != null || _mediaSource != null) {
      setState(_clearRecoveryMedia);
    }
    final l10n = AppLocalizations.of(context)!;
    final message =
        error is MobileAccountRecoveryMediaException &&
            error.failure == MobileAccountRecoveryMediaFailure.invalid
        ? l10n.cloudSyncAccountRecoveryMediaInvalid
        : l10n.cloudSyncAccountRecoveryFileReadFailed;
    showAppSnackBar(context, message: message, type: NotificationType.error);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final command = _buildCommand();
    if (command == null) return;
    setState(() => _submitting = true);
    final provider = context.read<CloudSyncProvider>();
    final recovered = await provider.startAccountRecovery(command);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (recovered) {
      await Navigator.of(context).maybePop(true);
      return;
    }
    final error = provider.lastError;
    if (error != null) {
      showAppSnackBar(
        context,
        message: cloudSyncFailureText(AppLocalizations.of(context)!, error),
        type: NotificationType.error,
      );
    }
  }

  E2eeAccountRecoveryCommand? _buildCommand() {
    final l10n = AppLocalizations.of(context)!;
    final loginName = _loginNameController.text.trim();
    final deviceName = _deviceNameController.text.trim();
    final password = _passwordController.text;
    final recoveryPassphrase = _recoveryPassphraseController.text;
    final media = _encryptedRecoveryMedia;
    if (loginName.isEmpty ||
        deviceName.isEmpty ||
        password.isEmpty ||
        recoveryPassphrase.isEmpty) {
      _showValidation(l10n.cloudSyncAccountRecoveryRequiredFields);
      return null;
    }
    if (media == null) {
      _showValidation(l10n.cloudSyncAccountRecoveryMediaRequired);
      return null;
    }
    if (sensitiveUtf8Equals(password, recoveryPassphrase)) {
      _showValidation(l10n.cloudSyncRecoveryPassphraseMatchesPassword);
      return null;
    }
    final passphraseError = switch (validateE2eeRecoveryPassphraseText(
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
    if (passphraseError != null) {
      _showValidation(passphraseError);
      return null;
    }

    Uint8List? passwordBytes;
    Uint8List? passphraseBytes;
    Uint8List? mediaCopy;
    try {
      passwordBytes = encodeSensitiveUtf8(password);
      passphraseBytes = encodeSensitiveUtf8(recoveryPassphrase);
      mediaCopy = Uint8List.fromList(media);
      final command = E2eeAccountRecoveryCommand(
        loginName: loginName,
        deviceName: deviceName,
        accountPassword: passwordBytes,
        recoveryPassphrase: passphraseBytes,
        encryptedRecoveryMedia: mediaCopy,
      );
      _passwordController.clear();
      _recoveryPassphraseController.clear();
      return command;
    } finally {
      clearSensitiveBytes(passwordBytes);
      clearSensitiveBytes(passphraseBytes);
      clearSensitiveBytes(mediaCopy);
    }
  }

  void _showValidation(String message) {
    showAppSnackBar(context, message: message, type: NotificationType.warning);
  }
}

String? _progressText(
  AppLocalizations l10n,
  E2eeAccountRecoveryProgress? progress,
) {
  return switch (progress) {
    null => null,
    E2eeAccountRecoveryProgress.authenticating =>
      l10n.cloudSyncAccountRecoveryAuthenticating,
    E2eeAccountRecoveryProgress.verifyingRecoveryMedia =>
      l10n.cloudSyncAccountRecoveryVerifying,
    E2eeAccountRecoveryProgress.rebuildingTrustedDevice =>
      l10n.cloudSyncAccountRecoveryRebuilding,
    E2eeAccountRecoveryProgress.restoringEncryptedData =>
      l10n.cloudSyncAccountRecoveryRestoring,
    E2eeAccountRecoveryProgress.completing =>
      l10n.cloudSyncAccountRecoveryCompleting,
    E2eeAccountRecoveryProgress.completed =>
      l10n.cloudSyncAccountRecoveryCompleted,
    E2eeAccountRecoveryProgress.failed => l10n.cloudSyncAccountRecoveryFailed,
  };
}

final class _RecoveryStatusPanel extends StatelessWidget {
  const _RecoveryStatusPanel({
    required this.icon,
    required this.message,
    required this.color,
    this.showProgress = false,
  });

  final IconData icon;
  final String message;
  final Color color;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (showProgress)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: AppFontWeights.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
