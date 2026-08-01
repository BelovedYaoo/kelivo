import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('账户恢复 checkpoint 密文可耐久重放并按摘要删除', () async {
    final root = await Directory.systemTemp.createTemp(
      'kelivo-account-recovery-store-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final store = DeviceStateBlobStore(installationRoot: root);
    const baseUrl = 'https://kelivo.bemylover.top';
    const loginName = 'ovo';
    await store.compareAndSwap(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      expectedVersion: null,
      blob: Uint8List(DeviceStateBlobStore.blobLength),
    );
    final envelope = Uint8List.fromList(<int>[1, 2, 3, 4]);

    await store.writePendingAccountRecoveryEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: envelope,
    );
    await store.writePendingAccountRecoveryEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: envelope,
    );

    expect(
      await store.readPendingAccountRecoveryEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      envelope,
    );
    final digest = Uint8List.fromList(sha256.convert(envelope).bytes);
    expect(
      await store.deletePendingAccountRecoveryEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        expectedDigest: digest,
      ),
      isTrue,
    );
    expect(
      await store.readPendingAccountRecoveryEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );
  });

  test('账户恢复 checkpoint 密文拒绝空载荷和超限载荷', () async {
    final root = await Directory.systemTemp.createTemp(
      'kelivo-account-recovery-store-boundary-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final store = DeviceStateBlobStore(installationRoot: root);

    expect(
      () => store.writePendingAccountRecoveryEnvelope(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'ovo',
        envelope: Uint8List(0),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => store.writePendingAccountRecoveryEnvelope(
        normalizedBaseUrl: 'https://kelivo.bemylover.top',
        normalizedLoginName: 'ovo',
        envelope: Uint8List(
          DeviceStateBlobStore.pendingAccountRecoveryEnvelopeMaxLength + 1,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
