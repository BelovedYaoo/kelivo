import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/backup.dart';
import 'mcp_provider.dart';
import '../services/chat/chat_service.dart';
import '../services/backup/data_sync.dart';

class BackupProvider extends ChangeNotifier {
  final DataSync _dataSync;
  LocalBackupOptions _options;
  bool _busy = false;

  BackupProvider({
    required ChatService chatService,
    required McpProvider mcpProvider,
    LocalBackupOptions? initialOptions,
  }) : _dataSync = DataSync(
         chatService: chatService,
         mcpBackupSettings: (
           snapshotServers: () async {
             await mcpProvider.ready;
             return jsonEncode(
               mcpProvider.servers
                   .map((server) => server.toJson())
                   .toList(growable: false),
             );
           },
           restoreServers: (rawJson) async {
             await mcpProvider.ready;
             await mcpProvider.replaceAllFromJson(rawJson, allowEmpty: true);
           },
         ),
       ),
       _options = initialOptions ?? const LocalBackupOptions();

  LocalBackupOptions get options => _options;
  bool get busy => _busy;

  void updateOptions(LocalBackupOptions options) {
    _options = options;
    notifyListeners();
  }

  Future<File> exportToFile() async {
    _busy = true;
    notifyListeners();
    try {
      return await _dataSync.prepareLocalExportFile(_options);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> restoreFromLocalFile(
    File file, {
    RestoreMode mode = RestoreMode.overwrite,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await _dataSync.restoreLocalFile(file, _options, mode: mode);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
