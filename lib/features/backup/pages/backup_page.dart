import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/backup.dart';
import '../../../core/providers/backup_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/backup/chatbox_importer.dart';
import '../../../core/services/backup/cherry_importer.dart';
import '../../../core/services/backup/data_sync.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/native_file_save.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/loading_dialog_card.dart';
import '../../../shared/widgets/snackbar.dart';
import '../backup_restart_dialog.dart';
import '../backup_restore_error_message.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BackupProvider>(
      create: (_) => BackupProvider(
        chatService: context.read<ChatService>(),
        mcpProvider: context.read<McpProvider>(),
      ),
      child: _LocalBackupContent(embedded: embedded),
    );
  }
}

class _LocalBackupContent extends StatefulWidget {
  const _LocalBackupContent({required this.embedded});

  final bool embedded;

  @override
  State<_LocalBackupContent> createState() => _LocalBackupContentState();
}

class _LocalBackupContentState extends State<_LocalBackupContent> {
  bool _operationInFlight = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final provider = context.watch<BackupProvider>();
    final content = ListView(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 24 : 16,
        widget.embedded ? 24 : 12,
        widget.embedded ? 24 : 16,
        24,
      ),
      children: <Widget>[
        if (widget.embedded) ...<Widget>[
          Text(
            localizations.backupPageTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
        ],
        _SectionLabel(localizations.backupPageBackupManagement),
        _SectionCard(
          children: <Widget>[
            _OptionRow(
              icon: Lucide.MessageSquare,
              label: localizations.backupPageChatsLabel,
              value: provider.options.includeChats,
              enabled: !_operationInFlight,
              onChanged: (value) {
                provider.updateOptions(
                  provider.options.copyWith(includeChats: value),
                );
              },
            ),
            const _SectionDivider(),
            _OptionRow(
              icon: Lucide.FileText,
              label: localizations.backupPageFilesLabel,
              value: provider.options.includeFiles,
              enabled: !_operationInFlight,
              onChanged: (value) {
                provider.updateOptions(
                  provider.options.copyWith(includeFiles: value),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionLabel(localizations.backupPageLocalBackup),
        _SectionCard(
          children: <Widget>[
            _ActionRow(
              icon: Lucide.Export,
              label: localizations.backupPageExportToFile,
              subtitle: localizations.backupPageExportToFileSubtitle,
              enabled: !_operationInFlight,
              onTap: () => unawaited(_exportLocalBackup(provider)),
            ),
            const _SectionDivider(),
            _ActionRow(
              icon: Lucide.Import2,
              label: localizations.backupPageImportBackupFile,
              subtitle: localizations.backupPageImportBackupFileSubtitle,
              enabled: !_operationInFlight,
              onTap: () => unawaited(_importLocalBackup(provider)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionLabel(localizations.backupPageImportFromOtherApps),
        _SectionCard(
          children: <Widget>[
            _ActionRow(
              icon: Lucide.Box,
              label: localizations.backupPageImportFromCherryStudio,
              enabled: !_operationInFlight,
              onTap: () => unawaited(_importCherryStudio()),
            ),
            const _SectionDivider(),
            _ActionRow(
              icon: Lucide.Box,
              label: localizations.backupPageImportFromChatbox,
              enabled: !_operationInFlight,
              onTap: () => unawaited(_importChatbox()),
            ),
          ],
        ),
      ],
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          minSize: 44,
          semanticLabel: localizations.settingsPageBackButton,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(localizations.backupPageTitle),
      ),
      body: content,
    );
  }

  Future<void> _exportLocalBackup(BackupProvider provider) async {
    final localizations = AppLocalizations.of(context)!;
    File? temporaryFile;
    _setOperationInFlight(true);
    try {
      final exportFile = await _runWithLoadingOverlay(
        () => provider.exportToFile(),
        label: localizations.backupPageExporting,
      );
      temporaryFile = exportFile;
      if (!mounted) return;
      if (Platform.isAndroid || Platform.isIOS) {
        await NativeFileSave.saveFileFromPath(
          sourcePath: exportFile.path,
          fileName: exportFile.uri.pathSegments.last,
        );
        return;
      }

      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: localizations.backupPageExportToFile,
        fileName: exportFile.uri.pathSegments.last,
        type: FileType.custom,
        allowedExtensions: const <String>['zip'],
      );
      if (targetPath == null) return;
      await File(targetPath).parent.create(recursive: true);
      await exportFile.copy(targetPath);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: localizations.backupPageExportFailedMessage(error.toString()),
        type: NotificationType.error,
      );
    } finally {
      try {
        await DataSync.cleanupTemporaryLocalExportFile(temporaryFile);
      } finally {
        _setOperationInFlight(false);
      }
    }
  }

  Future<void> _importLocalBackup(BackupProvider provider) async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    final path = selected?.files.single.path;
    if (path == null || !mounted) return;
    final mode = await _chooseRestoreMode();
    if (mode == null || !mounted) return;

    _setOperationInFlight(true);
    try {
      await _runWithLoadingOverlay(
        () => provider.restoreFromLocalFile(File(path), mode: mode),
      );
    } catch (error) {
      _showRestoreError(error);
      return;
    } finally {
      _setOperationInFlight(false);
    }
    if (mounted) await showBackupRestartRequiredDialog(context);
  }

  Future<void> _importCherryStudio() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['zip', 'bak'],
    );
    final path = selected?.files.single.path;
    if (path == null || !mounted) return;
    final mode = await _chooseRestoreMode();
    if (mode == null || !mounted) return;

    _setOperationInFlight(true);
    try {
      await _runWithLoadingOverlay(
        () => CherryImporter.importFromCherryStudio(
          file: File(path),
          mode: mode,
          settings: context.read<SettingsProvider>(),
          chatService: context.read<ChatService>(),
        ),
      );
    } catch (error) {
      _showRestoreError(error);
      return;
    } finally {
      _setOperationInFlight(false);
    }
    if (mounted) await showBackupRestartRequiredDialog(context);
  }

  Future<void> _importChatbox() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    final path = selected?.files.single.path;
    if (path == null || !mounted) return;
    final mode = await _chooseRestoreMode();
    if (mode == null || !mounted) return;

    _setOperationInFlight(true);
    try {
      await _runWithLoadingOverlay(
        () => ChatboxImporter.importFromChatbox(
          file: File(path),
          mode: mode,
          settings: context.read<SettingsProvider>(),
          chatService: context.read<ChatService>(),
        ),
      );
    } catch (error) {
      _showRestoreError(error);
      return;
    } finally {
      _setOperationInFlight(false);
    }
    if (mounted) await showBackupRestartRequiredDialog(context);
  }

  Future<RestoreMode?> _chooseRestoreMode() {
    final localizations = AppLocalizations.of(context)!;
    return showDialog<RestoreMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.backupPageSelectImportMode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(localizations.backupPageSelectImportModeDescription),
            const SizedBox(height: 12),
            _RestoreModeButton(
              title: localizations.backupPageOverwriteMode,
              description: localizations.backupPageOverwriteModeDescription,
              onTap: () =>
                  Navigator.of(dialogContext).pop(RestoreMode.overwrite),
            ),
            const SizedBox(height: 8),
            _RestoreModeButton(
              title: localizations.backupPageMergeMode,
              description: localizations.backupPageMergeModeDescription,
              onTap: () => Navigator.of(dialogContext).pop(RestoreMode.merge),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations.backupPageCancel),
          ),
        ],
      ),
    );
  }

  Future<T> _runWithLoadingOverlay<T>(
    Future<T> Function() operation, {
    String? label,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LoadingDialogCard(label: label),
    );
    try {
      return await operation();
    } finally {
      if (navigator.mounted) navigator.pop();
    }
  }

  void _showRestoreError(Object error) {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      message: localizations.backupPageRestoreFailedMessage(
        backupRestoreErrorMessage(localizations, error),
      ),
      type: NotificationType.error,
    );
  }

  void _setOperationInFlight(bool value) {
    if (!mounted || _operationInFlight == value) return;
    setState(() => _operationInFlight = value);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.72),
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.36),
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
      height: 1,
      indent: 48,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.28),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(child: Text(label)),
            IosSwitch(
              value: value,
              onChanged: enabled ? onChanged : null,
              semanticLabel: label,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IosCardPress(
      onTap: enabled ? onTap : null,
      haptics: enabled,
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: 20,
            color: enabled
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.38),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    color: enabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.46),
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Lucide.ChevronRight,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.42),
          ),
        ],
      ),
    );
  }
}

class _RestoreModeButton extends StatelessWidget {
  const _RestoreModeButton({
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.45),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
