import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../core/services/sync/e2ee_first_device_registration_commit_coordinator.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../theme/app_font_weights.dart';

typedef MobileRecoveryMediaFileSaver = Future<bool> Function(Uint8List media);

enum MobileRecoveryMediaExportResult { confirmed, cancelled, fileSaveFailed }

Future<bool> saveMobileRecoveryMediaFile(Uint8List media) async {
  final path = await FilePicker.platform.saveFile(
    fileName: 'kelivo-recovery-v1.kelivo-recovery',
    type: FileType.custom,
    allowedExtensions: const <String>['kelivo-recovery'],
    bytes: media,
  );
  return path != null && path.trim().isNotEmpty;
}

final class MobileRecoveryMediaExportPage extends StatefulWidget {
  MobileRecoveryMediaExportPage({
    super.key,
    required Uint8List encryptedMedia,
    this.fileSaver = saveMobileRecoveryMediaFile,
  }) : encryptedMedia = _requireEncryptedRecoveryMedia(encryptedMedia);

  final Uint8List encryptedMedia;
  final MobileRecoveryMediaFileSaver fileSaver;

  @override
  State<MobileRecoveryMediaExportPage> createState() =>
      _MobileRecoveryMediaExportPageState();
}

final class _MobileRecoveryMediaExportPageState
    extends State<MobileRecoveryMediaExportPage> {
  QrImage? _qrImage;
  bool _fileSaved = false;
  bool _acknowledged = false;
  bool _savingFile = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    try {
      _qrImage = QrImage(
        QrCode.fromUint8List(
          data: widget.encryptedMedia,
          errorCorrectLevel: QrErrorCorrectLevel.L,
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        '生成恢复介质二维码失败',
        name: 'Kelivo.MobileRecoveryMediaExport',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
      // 文件导出仍是显式可见的恢复路径，二维码失败不能伪装成成功。
      _qrImage = null;
    }
  }

  @override
  void dispose() {
    _qrImage = null;
    widget.encryptedMedia.fillRange(0, widget.encryptedMedia.length, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final exportAvailable = _qrImage != null || _fileSaved;
    return PopScope<MobileRecoveryMediaExportResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(MobileRecoveryMediaExportResult.cancelled);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IosIconButton(
            key: const ValueKey<String>('mobile-recovery-export-cancel'),
            icon: Lucide.X,
            minSize: 44,
            semanticLabel: l10n.cloudSyncRecoveryMediaCancel,
            enabled: !_savingFile,
            onTap: () => _finish(MobileRecoveryMediaExportResult.cancelled),
          ),
          title: Text(l10n.cloudSyncRecoveryMediaTitle),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                l10n.cloudSyncRecoveryMediaIntro,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              if (_qrImage case final qrImage?)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: PrettyQrView(
                                qrImage: qrImage,
                                decoration: const PrettyQrDecoration(
                                  quietZone: PrettyQrQuietZone.modules(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.cloudSyncRecoveryMediaQrLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _StatusPanel(
                  icon: Lucide.TriangleAlert,
                  message: l10n.cloudSyncRecoveryMediaQrUnavailable,
                  color: colorScheme.error,
                ),
              const SizedBox(height: 16),
              IosTileButton(
                key: const ValueKey<String>('mobile-recovery-export-save-file'),
                label: _savingFile
                    ? l10n.cloudSyncRecoveryMediaSavingFile
                    : l10n.cloudSyncRecoveryMediaSaveFile,
                icon: Lucide.Download,
                enabled: !_savingFile && !_finishing,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.primary,
                onTap: () => _saveFile(),
              ),
              if (_fileSaved) ...[
                const SizedBox(height: 12),
                _StatusPanel(
                  key: const ValueKey<String>(
                    'mobile-recovery-export-file-saved',
                  ),
                  icon: Lucide.CheckCircle,
                  message: l10n.cloudSyncRecoveryMediaFileSaved,
                  color: colorScheme.primary,
                ),
              ],
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IosCheckbox(
                        key: const ValueKey<String>(
                          'mobile-recovery-export-acknowledgement',
                        ),
                        value: _acknowledged,
                        semanticLabel:
                            l10n.cloudSyncRecoveryMediaAcknowledgement,
                        onChanged: exportAvailable && !_savingFile
                            ? (value) => setState(() => _acknowledged = value)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.cloudSyncRecoveryMediaAcknowledgement,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: AppFontWeights.medium,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              IosTileButton(
                key: const ValueKey<String>('mobile-recovery-export-confirm'),
                label: l10n.cloudSyncRecoveryMediaConfirm,
                icon: Lucide.ArrowRight,
                enabled:
                    exportAvailable &&
                    _acknowledged &&
                    !_savingFile &&
                    !_finishing,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.primary,
                onTap: () => _finish(MobileRecoveryMediaExportResult.confirmed),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveFile() async {
    if (_savingFile || _finishing) return;
    setState(() => _savingFile = true);
    late final bool saved;
    try {
      saved = await widget.fileSaver(widget.encryptedMedia);
    } catch (error, stackTrace) {
      developer.log(
        '保存恢复介质文件失败',
        name: 'Kelivo.MobileRecoveryMediaExport',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
      saved = false;
    }
    if (!mounted) return;
    if (!saved) {
      _finish(MobileRecoveryMediaExportResult.fileSaveFailed);
      return;
    }
    setState(() {
      _savingFile = false;
      _fileSaved = true;
    });
  }

  void _finish(MobileRecoveryMediaExportResult result) {
    if (_finishing || !mounted) return;
    _finishing = true;
    Navigator.of(context).pop(result);
  }
}

final class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    super.key,
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontSize: 14, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Uint8List _requireEncryptedRecoveryMedia(Uint8List media) {
  if (media.length != e2eeEncryptedRecoveryMediaBytes) {
    throw ArgumentError.value(media.length, 'encryptedMedia', '恢复介质长度无效');
  }
  return media;
}
