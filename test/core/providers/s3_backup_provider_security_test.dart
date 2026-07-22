import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/test_database_cipher.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/database/chat_database_gateway.dart';
import 'package:Kelivo/core/providers/s3_backup_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('S3BackupProvider restore paths', () {
    late Directory root;
    late PathProviderPlatform previousPathProvider;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_s3_provider_security_',
      );
      previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(root.path);
      SharedPreferences.setMockInitialValues({});
      Hive.init(root.path);
    });

    tearDown(() async {
      await Hive.close();
      PathProviderPlatform.instance = previousPathProvider;
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('ignores untrusted display names and cleans temp files', () async {
      final settingsFile = File('${root.path}/settings.json');
      await settingsFile.writeAsString('{}');
      final remoteBackup = File('${root.path}/remote.zip');
      final encoder = ZipFileEncoder();
      encoder.create(remoteBackup.path);
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.closeSync();
      final remoteBackupBytes = await remoteBackup.readAsBytes();

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.add(remoteBackupBytes);
        await request.response.close();
      });

      final chatService = ChatService(
        const UntrackedSyncWriteExecutor.forTests(),
        databaseGateway: ChatDatabaseGateway(cipher: testDatabaseCipher),
      );
      addTearDown(chatService.close);
      final provider = S3BackupProvider(
        chatService: chatService,
        initialConfig: S3Config(
          endpoint: 'http://${server.address.address}:${server.port}',
          bucket: 'backup-bucket',
          accessKeyId: 'test-access-key',
          secretAccessKey: 'test-secret-key',
          includeChats: false,
          includeFiles: false,
        ),
      );
      addTearDown(provider.dispose);

      final relativeSentinel = File('${root.path}/s3_relative.zip');
      final absoluteSentinel = File('${root.path}/s3_absolute.zip');
      await relativeSentinel.writeAsString('keep relative');
      await absoluteSentinel.writeAsString('keep absolute');
      final remoteNames = <String>['../s3_relative.zip', absoluteSentinel.path];

      for (var i = 0; i < remoteNames.length; i++) {
        await provider.restoreFromItem(
          BackupFileItem(
            href: Uri.parse('s3://backup-bucket/kelivo_backups/remote_$i.zip'),
            displayName: remoteNames[i],
            size: remoteBackupBytes.length,
            lastModified: null,
          ),
        );
      }

      expect(await relativeSentinel.readAsString(), 'keep relative');
      expect(await absoluteSentinel.readAsString(), 'keep absolute');
      expect(await Directory('${root.path}/tmp').list().toList(), isEmpty);
    });
  });
}
