import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _phase = String.fromEnvironment(
  'KELIVO_ANDROID_KEY_SLOT_TEST_PHASE',
  defaultValue: 'lifecycle',
);
const _restartCreatePhase = 'restart-create';
const _restartOpenPhase = 'restart-open';

final _lifecycleSlotId = _identifier(0x90);
final _concurrentSlotId = _identifier(0xa0);
final _restartSlotId = _identifier(0xb0);
final _recordId = _identifier(0xc0);
final _associatedData = Uint8List.fromList(<int>[
  0x4b,
  0x45,
  0x4c,
  0x49,
  0x56,
  0x4f,
]);
final _initialPlaintext = Uint8List.fromList(<int>[1, 3, 3, 7]);
final _updatedPlaintext = Uint8List.fromList(<int>[2, 4, 6, 8]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (_phase == _restartCreatePhase) {
    testWidgets('Android 安全槽进程重启前写入密文', (tester) async {
      await _writeRestartFixture();
    });
    return;
  }
  if (_phase == _restartOpenPhase) {
    testWidgets('Android 安全槽进程重启后可解密并删除', (tester) async {
      await _openRestartFixture();
    });
    return;
  }
  if (_phase != 'lifecycle') {
    throw StateError('android_key_slot_test_phase');
  }

  testWidgets('Android 全新安装可完成隔离安全槽生命周期', (tester) async {
    expect(Platform.isAndroid, isTrue);
    final secureCore = const KelivoSecureCore();
    KelivoKeyHandle? handle;

    try {
      handle = await secureCore.createSlot(_lifecycleSlotId);
      final initialEnvelope = await secureCore.sealRecord(
        handle,
        recordId: _recordId,
        epoch: 1,
        associatedData: _associatedData,
        plaintext: _initialPlaintext,
      );
      await secureCore.close(handle);
      handle = null;

      handle = await secureCore.openSlot(_lifecycleSlotId);
      expect(
        await secureCore.openRecord(
          handle,
          recordId: _recordId,
          epoch: 1,
          associatedData: _associatedData,
          envelope: initialEnvelope,
        ),
        orderedEquals(_initialPlaintext),
      );
      final updatedEnvelope = await secureCore.sealRecord(
        handle,
        recordId: _recordId,
        epoch: 1,
        associatedData: _associatedData,
        plaintext: _updatedPlaintext,
      );

      await expectLater(
        secureCore.deleteSlot(_lifecycleSlotId),
        throwsA(_hasStatus(KelivoSecureCoreStatus.slotInUse)),
      );
      await secureCore.close(handle);
      handle = null;

      handle = await secureCore.openSlot(_lifecycleSlotId);
      expect(
        await secureCore.openRecord(
          handle,
          recordId: _recordId,
          epoch: 1,
          associatedData: _associatedData,
          envelope: updatedEnvelope,
        ),
        orderedEquals(_updatedPlaintext),
      );
      await secureCore.close(handle);
      handle = null;
      await secureCore.deleteSlot(_lifecycleSlotId);
      await expectLater(
        secureCore.openSlot(_lifecycleSlotId),
        throwsA(_hasStatus(KelivoSecureCoreStatus.slotNotFound)),
      );
    } finally {
      if (handle != null) await secureCore.close(handle);
      await secureCore.deleteSlot(_lifecycleSlotId);
    }
  });

  testWidgets('Android 并发创建同一隔离槽仅有一个成功', (tester) async {
    expect(Platform.isAndroid, isTrue);
    final secureCore = const KelivoSecureCore();

    try {
      final results = await Future.wait(<Future<_CreateResult>>[
        _tryCreate(secureCore, _concurrentSlotId),
        _tryCreate(secureCore, _concurrentSlotId),
      ]);
      final handles = results
          .map((result) => result.handle)
          .whereType<KelivoKeyHandle>()
          .toList(growable: false);
      final errors = results
          .map((result) => result.error)
          .whereType<KelivoSecureCoreException>()
          .toList(growable: false);

      expect(handles, hasLength(1));
      expect(errors, hasLength(1));
      expect(errors.single.status, KelivoSecureCoreStatus.slotAlreadyExists);
      await secureCore.close(handles.single);
    } finally {
      await secureCore.deleteSlot(_concurrentSlotId);
    }
  });
}

Future<void> _writeRestartFixture() async {
  expect(Platform.isAndroid, isTrue);
  final secureCore = const KelivoSecureCore();
  final envelopeFile = await _restartEnvelopeFile();
  expect(
    await FileSystemEntity.type(envelopeFile.path, followLinks: false),
    FileSystemEntityType.notFound,
  );
  final handle = await secureCore.createSlot(_restartSlotId);
  try {
    final envelope = await secureCore.sealRecord(
      handle,
      recordId: _recordId,
      epoch: 1,
      associatedData: _associatedData,
      plaintext: _initialPlaintext,
    );
    final persisted = Uint8List(8 + envelope.length);
    ByteData.sublistView(persisted).setUint64(0, pid, Endian.big);
    persisted.setRange(8, persisted.length, envelope);
    await envelopeFile.writeAsBytes(persisted, flush: true);
  } finally {
    await secureCore.close(handle);
  }
}

Future<void> _openRestartFixture() async {
  expect(Platform.isAndroid, isTrue);
  final secureCore = const KelivoSecureCore();
  final envelopeFile = await _restartEnvelopeFile();
  expect(
    await FileSystemEntity.type(envelopeFile.path, followLinks: false),
    FileSystemEntityType.file,
  );
  KelivoKeyHandle? handle;
  try {
    final persisted = await envelopeFile.readAsBytes();
    expect(persisted.length, greaterThan(8));
    final creatorProcessId = ByteData.sublistView(
      persisted,
    ).getUint64(0, Endian.big);
    expect(creatorProcessId, isNot(pid));
    final envelope = Uint8List.sublistView(persisted, 8);
    handle = await secureCore.openSlot(_restartSlotId);
    expect(
      await secureCore.openRecord(
        handle,
        recordId: _recordId,
        epoch: 1,
        associatedData: _associatedData,
        envelope: envelope,
      ),
      orderedEquals(_initialPlaintext),
    );
    await secureCore.close(handle);
    handle = null;
    await secureCore.deleteSlot(_restartSlotId);
    await envelopeFile.delete();
    await expectLater(
      secureCore.openSlot(_restartSlotId),
      throwsA(_hasStatus(KelivoSecureCoreStatus.slotNotFound)),
    );
  } finally {
    if (handle != null) await secureCore.close(handle);
  }
}

Future<_CreateResult> _tryCreate(
  KelivoSecureCore secureCore,
  Uint8List slotId,
) async {
  try {
    return _CreateResult(handle: await secureCore.createSlot(slotId));
  } on KelivoSecureCoreException catch (error) {
    return _CreateResult(error: error);
  }
}

Matcher _hasStatus(KelivoSecureCoreStatus status) =>
    isA<KelivoSecureCoreException>().having(
      (error) => error.status,
      'status',
      status,
    );

Future<File> _restartEnvelopeFile() async => File(
  p.join(
    (await getApplicationSupportDirectory()).path,
    'kelivo-issue90-restart-envelope.bin',
  ),
);

Uint8List _identifier(int prefix) =>
    Uint8List.fromList(List<int>.generate(16, (index) => prefix ^ index));

final class _CreateResult {
  const _CreateResult({this.handle, this.error})
    : assert((handle == null) != (error == null));

  final KelivoKeyHandle? handle;
  final KelivoSecureCoreException? error;
}
