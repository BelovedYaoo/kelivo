import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';

void main() {
  group('RestorePlatformDurability', () {
    late Directory root;
    late RestorePlatformDurability durability;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_durability_test_',
      );
      durability = RestorePlatformDurability();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('syncs regular files and directories', () async {
      final file = File(p.join(root.path, 'payload.bin'));
      await file.writeAsBytes([1, 2, 3], flush: true);

      await durability.restrictFile(file);
      await durability.restrictDirectory(root);
      await durability.syncFile(file, fullBarrier: true);
      await durability.syncDirectory(root);
      await durability.syncDirectory(root, fullBarrier: true);

      expect(await file.readAsBytes(), [1, 2, 3]);
      if (!Platform.isWindows) {
        expect((await file.stat()).mode & 0x1ff, 0x180);
        expect((await root.stat()).mode & 0x1ff, 0x1c0);
      }
    });

    test('Windows 原生持久化支持超过 MAX_PATH 的受管路径', () async {
      if (!Platform.isWindows) return;

      var deepDirectory = root;
      var segment = 0;
      while (p.join(deepDirectory.path, 'payload.bin').length <= 270) {
        deepDirectory = Directory(
          p.join(
            deepDirectory.path,
            'segment_${segment.toString().padLeft(2, '0')}_0123456789',
          ),
        );
        await deepDirectory.create();
        segment++;
      }
      final source = File(p.join(deepDirectory.path, 'payload.bin'));
      final target = p.join(deepDirectory.path, 'published.bin');
      await source.writeAsBytes([7, 8, 9], flush: true);
      expect(source.absolute.path.length, greaterThan(260));

      await durability.syncFile(source, fullBarrier: true);
      await durability.syncDirectory(deepDirectory, fullBarrier: true);
      await durability.renameAndSync(source: source, targetPath: target);

      expect(await source.exists(), isFalse);
      expect(await File(target).readAsBytes(), [7, 8, 9]);
    });

    test(
      'renames files across directories and persists both parents',
      () async {
        final sourceParent = Directory(p.join(root.path, 'source'));
        final targetParent = Directory(p.join(root.path, 'target'));
        await sourceParent.create();
        await targetParent.create();
        final source = File(p.join(sourceParent.path, 'payload.bin'));
        final target = p.join(targetParent.path, 'payload.bin');
        await source.writeAsBytes([4, 5, 6], flush: true);

        await durability.renameAndSync(source: source, targetPath: target);

        expect(await source.exists(), isFalse);
        expect(await File(target).readAsBytes(), [4, 5, 6]);
      },
    );

    test('renames directories without replacing a target', () async {
      final source = Directory(p.join(root.path, 'source'));
      await source.create();
      await File(p.join(source.path, 'item')).writeAsString('value');
      final target = p.join(root.path, 'target');

      await durability.renameAndSync(source: source, targetPath: target);

      expect(await source.exists(), isFalse);
      expect(await File(p.join(target, 'item')).readAsString(), 'value');
      final collision = File(p.join(root.path, 'collision'));
      await collision.writeAsString('existing');
      await expectLater(
        durability.renameAndSync(
          source: File(p.join(target, 'item')),
          targetPath: collision.path,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await collision.readAsString(), 'existing');
    });

    test('rejects links instead of syncing their targets', () async {
      if (Platform.isWindows) return;
      final target = File(p.join(root.path, 'target'));
      await target.writeAsString('value');
      final link = Link(p.join(root.path, 'link'));
      await link.create(target.path);

      await expectLater(
        durability.syncFile(File(link.path)),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
