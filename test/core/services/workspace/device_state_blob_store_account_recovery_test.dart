import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:Kelivo/core/services/workspace/e2ee_data_rekey_stage_store.dart';
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
    final replacement = Uint8List.fromList(<int>[5, 6, 7, 8]);

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
    await store.replacePendingAccountRecoveryEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      expectedDigest: digest,
      envelope: replacement,
    );
    await store.replacePendingAccountRecoveryEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      expectedDigest: digest,
      envelope: replacement,
    );
    expect(
      await store.readPendingAccountRecoveryEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      replacement,
    );
    final replacementDigest = Uint8List.fromList(
      sha256.convert(replacement).bytes,
    );
    expect(
      await store.deletePendingAccountRecoveryEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        expectedDigest: replacementDigest,
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

  test('data-rekey 随机密文按 operation 耐久重放并逐项清理', () async {
    final root = await Directory.systemTemp.createTemp(
      'kelivo-data-rekey-stage-store-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    const baseUrl = 'https://kelivo.bemylover.top';
    const loginName = 'ovo';
    const operationId = '11111111-1111-4111-8111-111111111111';
    const firstArtifactId = '22222222-2222-4222-8222-222222222222';
    const secondArtifactId = '33333333-3333-4333-8333-333333333333';
    final first = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final second = Uint8List.fromList(<int>[5, 6, 7, 8]);
    final store = E2eeDataRekeyStageStore(installationRoot: root);

    await store.writePendingArtifact(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      operationId: operationId,
      artifactId: secondArtifactId,
      maximumCount: 2,
      envelope: second,
    );
    await store.writePendingArtifact(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      operationId: operationId,
      artifactId: firstArtifactId,
      maximumCount: 2,
      envelope: first,
    );
    await store.writePendingArtifact(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      operationId: operationId,
      artifactId: firstArtifactId,
      maximumCount: 2,
      envelope: first,
    );

    final reopened = E2eeDataRekeyStageStore(installationRoot: root);
    expect(
      await reopened.listArtifactIds(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        operationId: operationId,
        maximumCount: 2,
      ),
      <String>[firstArtifactId, secondArtifactId],
    );
    final pending = await reopened.readArtifact(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      operationId: operationId,
      artifactId: firstArtifactId,
    );
    expect(pending?.state, E2eeDataRekeyStageArtifactState.requestPending);
    expect(pending?.envelope, first);
    await expectLater(
      reopened.writePendingArtifact(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        operationId: operationId,
        artifactId: firstArtifactId,
        maximumCount: 2,
        envelope: second,
      ),
      throwsStateError,
    );
    final confirmation = Uint8List(84)..fillRange(0, 84, 9);
    await reopened.confirmArtifact(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      operationId: operationId,
      artifactId: firstArtifactId,
      expectedRequestDigest: Uint8List.fromList(sha256.convert(first).bytes),
      confirmedEnvelope: confirmation,
    );
    final confirmed = await E2eeDataRekeyStageStore(installationRoot: root)
        .readArtifact(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
          operationId: operationId,
          artifactId: firstArtifactId,
        );
    expect(confirmed?.state, E2eeDataRekeyStageArtifactState.confirmed);
    expect(confirmed?.envelope, confirmation);
    await expectLater(
      reopened.listArtifactIds(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        operationId: operationId,
        maximumCount: 1,
      ),
      throwsStateError,
    );
    await reopened.clearOperation(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      operationId: operationId,
      maximumCount: 2,
    );
    expect(
      await reopened.listArtifactIds(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        operationId: operationId,
        maximumCount: 2,
      ),
      isEmpty,
    );
  });
}
