import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import 'package:Kelivo/core/services/sync/e2ee_account_authenticator.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_trust_manifest.dart';
import 'package:Kelivo/core/services/sync/e2ee_first_device_recovery_bootstrap.dart';
import 'package:Kelivo/core/services/sync/e2ee_first_device_registration_commit_coordinator.dart';

const _serviceOrigin = 'https://kelivo.bemylover.top';
const _userId = '40000000-0000-4000-8000-000000000001';
const _operationId = '00000000-0000-4000-8000-000000000001';
const _deviceId = '20000000-0000-4000-8000-000000000001';

void main() {
  group('首设备恢复安全 bootstrap', () {
    test('注册 UI 口令预检与安全核心的字符和 UTF-8 字节边界一致', () {
      expect(
        validateE2eeRecoveryPassphraseText('12345678901'),
        E2eeRecoveryPassphraseValidation.tooShort,
      );
      expect(
        validateE2eeRecoveryPassphraseText('甲乙丙丁戊己庚辛壬癸子丑'),
        E2eeRecoveryPassphraseValidation.valid,
      );
      expect(
        validateE2eeRecoveryPassphraseText(
          List<String>.filled(128, 'a').join(),
        ),
        E2eeRecoveryPassphraseValidation.valid,
      );
      expect(
        validateE2eeRecoveryPassphraseText(
          List<String>.filled(129, 'a').join(),
        ),
        E2eeRecoveryPassphraseValidation.tooLong,
      );
    });

    test('prepare 仅生成恢复介质，由耐久提交器另行确认导出', () async {
      final context = await _BootstrapContext.create();
      addTearDown(context.close);
      final passphrase = _validPassphrase();
      final recoveryCore = _FakeFirstDeviceRecoveryCore(
        recoveryPublicKey: context.recoveryPublicKey,
      );
      final exportStarted = Completer<void>();
      final exportAck = Completer<bool>();
      Uint8List? exportedMedia;
      final preparer = E2eeFirstDeviceRecoveryBootstrapPreparer.forTesting(
        recoveryPassphrase: passphrase,
        serviceOrigin: _serviceOrigin,
        encryptedMediaExporter: (media) async {
          exportedMedia = media;
          exportStarted.complete();
          return exportAck.future;
        },
        recoveryCore: recoveryCore,
      );
      expect(passphrase, everyElement(0));

      final prepared = await preparer.prepare(
        accountRootKey: context.ark,
        userId: _userId,
        operationId: _operationId,
        localMember: context.localMember,
      );
      expect(exportStarted.isCompleted, isFalse);
      final encryptedMedia = prepared.takeEncryptedRecoveryMedia();
      final exportFuture = preparer.exportEncryptedRecoveryMedia(
        encryptedMedia,
      );

      await exportStarted.future;
      await Future<void>.delayed(Duration.zero);
      expect(encryptedMedia, everyElement(0xa7));
      exportAck.complete(true);
      expect(await exportFuture, isTrue);

      expect(passphrase, everyElement(0));
      expect(recoveryCore.closeCount, 1);
      expect(exportedMedia, hasLength(e2eeEncryptedRecoveryMediaBytes));
      expect(exportedMedia, everyElement(0));
      expect(encryptedMedia, everyElement(0));
      expect(
        recoveryCore.serviceOriginSha256,
        orderedEquals(
          _hexBytes(
            'ea8186ed7b738c5e7d26d2d10eb72bc8d10acb9fbc1495ef3715f1691e31409f',
          ),
        ),
      );
      expect(
        recoveryCore.validatedPassphrase,
        orderedEquals(utf8.encode('correct horse battery staple')),
      );
      expect(
        recoveryCore.initialCapsule,
        orderedEquals(prepared.securityState.recoveryCapsule),
      );
      expect(
        recoveryCore.genesisManifest,
        orderedEquals(prepared.membership.manifest),
      );
      expect(
        prepared.membership.recoveryCapsuleDigest,
        orderedEquals(
          sha256.convert(prepared.securityState.recoveryCapsule).bytes,
        ),
      );
      final verified = await const E2eeAccountTrustManifestModule().verify(
        ark: context.ark,
        expectation: E2eeInitializeMembershipExpectation(
          projection: _projection(prepared),
          operationId: _operationId,
          member: context.localMember,
        ),
      );
      expect(verified.digest, orderedEquals(prepared.membership.digest));
    });

    test('过短恢复口令在生成恢复身份前失败并被清零', () async {
      final context = await _BootstrapContext.create();
      addTearDown(context.close);
      final passphrase = Uint8List.fromList(utf8.encode('too-short'));
      var exporterCalled = false;
      final preparer = E2eeFirstDeviceRecoveryBootstrapPreparer(
        recoveryPassphrase: passphrase,
        serviceOrigin: _serviceOrigin,
        encryptedMediaExporter: (media) async {
          exporterCalled = true;
          return true;
        },
      );

      await expectLater(
        preparer.prepare(
          accountRootKey: context.ark,
          userId: _userId,
          operationId: _operationId,
          localMember: context.localMember,
        ),
        throwsArgumentError,
      );

      expect(passphrase, everyElement(0));
      expect(exporterCalled, isFalse);
    });

    test('非法 UTF-8 恢复口令失败并被清零', () async {
      final context = await _BootstrapContext.create();
      addTearDown(context.close);
      final passphrase = Uint8List.fromList(<int>[
        0xff,
        ...List<int>.filled(12, 0x61),
      ]);
      final preparer = E2eeFirstDeviceRecoveryBootstrapPreparer(
        recoveryPassphrase: passphrase,
        serviceOrigin: _serviceOrigin,
        encryptedMediaExporter: (media) async => true,
      );

      await expectLater(
        preparer.prepare(
          accountRootKey: context.ark,
          userId: _userId,
          operationId: _operationId,
          localMember: context.localMember,
        ),
        throwsArgumentError,
      );

      expect(passphrase, everyElement(0));
    });

    test('exporter 未确认时返回失败并清零已生成介质', () async {
      final context = await _BootstrapContext.create();
      addTearDown(context.close);
      final passphrase = _validPassphrase();
      final recoveryCore = _FakeFirstDeviceRecoveryCore(
        recoveryPublicKey: context.recoveryPublicKey,
      );
      final preparer = E2eeFirstDeviceRecoveryBootstrapPreparer.forTesting(
        recoveryPassphrase: passphrase,
        serviceOrigin: _serviceOrigin,
        encryptedMediaExporter: (media) async => false,
        recoveryCore: recoveryCore,
      );

      final prepared = await preparer.prepare(
        accountRootKey: context.ark,
        userId: _userId,
        operationId: _operationId,
        localMember: context.localMember,
      );
      final encryptedMedia = prepared.takeEncryptedRecoveryMedia();
      expect(
        await preparer.exportEncryptedRecoveryMedia(encryptedMedia),
        isFalse,
      );

      expect(passphrase, everyElement(0));
      expect(recoveryCore.closeCount, 1);
      expect(recoveryCore.media, everyElement(0));
      expect(encryptedMedia, everyElement(0));
    });

    test('exporter 异常时清理恢复资源并保留原始错误', () async {
      final context = await _BootstrapContext.create();
      addTearDown(context.close);
      final passphrase = _validPassphrase();
      final recoveryCore = _FakeFirstDeviceRecoveryCore(
        recoveryPublicKey: context.recoveryPublicKey,
      );
      final preparer = E2eeFirstDeviceRecoveryBootstrapPreparer.forTesting(
        recoveryPassphrase: passphrase,
        serviceOrigin: _serviceOrigin,
        encryptedMediaExporter: (media) async {
          throw const FormatException('恢复文件写入失败');
        },
        recoveryCore: recoveryCore,
      );

      final prepared = await preparer.prepare(
        accountRootKey: context.ark,
        userId: _userId,
        operationId: _operationId,
        localMember: context.localMember,
      );
      final encryptedMedia = prepared.takeEncryptedRecoveryMedia();
      await expectLater(
        preparer.exportEncryptedRecoveryMedia(encryptedMedia),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '恢复文件写入失败',
          ),
        ),
      );

      expect(passphrase, everyElement(0));
      expect(recoveryCore.closeCount, 1);
      expect(recoveryCore.media, everyElement(0));
      expect(encryptedMedia, everyElement(0));
    });

    test('仅接受规范的新服务 origin 并在拒绝时清零口令', () {
      for (final origin in <String>[
        'https://kelivo-api.ovo-a1f.workers.dev',
        'https://kelivo.bemylover.top/',
        'http://kelivo.bemylover.top',
      ]) {
        final passphrase = _validPassphrase();

        expect(
          () => E2eeFirstDeviceRecoveryBootstrapPreparer(
            recoveryPassphrase: passphrase,
            serviceOrigin: origin,
            encryptedMediaExporter: (media) async => true,
          ),
          throwsArgumentError,
        );
        expect(passphrase, everyElement(0));
      }
    });

    test('preparer 只能消费一次', () async {
      final context = await _BootstrapContext.create();
      addTearDown(context.close);
      final recoveryCore = _FakeFirstDeviceRecoveryCore(
        recoveryPublicKey: context.recoveryPublicKey,
      );
      var exporterCalls = 0;
      final preparer = E2eeFirstDeviceRecoveryBootstrapPreparer.forTesting(
        recoveryPassphrase: _validPassphrase(),
        serviceOrigin: _serviceOrigin,
        encryptedMediaExporter: (media) async {
          exporterCalls += 1;
          return true;
        },
        recoveryCore: recoveryCore,
      );
      final prepared = await preparer.prepare(
        accountRootKey: context.ark,
        userId: _userId,
        operationId: _operationId,
        localMember: context.localMember,
      );
      final encryptedMedia = prepared.takeEncryptedRecoveryMedia();
      expect(
        await preparer.exportEncryptedRecoveryMedia(encryptedMedia),
        isTrue,
      );

      await expectLater(
        preparer.prepare(
          accountRootKey: context.ark,
          userId: _userId,
          operationId: _operationId,
          localMember: context.localMember,
        ),
        throwsStateError,
      );

      expect(exporterCalls, 1);
      expect(encryptedMedia, everyElement(0));
      expect(recoveryCore.closeCount, 1);
    });

    test('prepare 前主动关闭会清零口令且永久拒绝生成', () async {
      final context = await _BootstrapContext.create();
      addTearDown(context.close);
      final passphrase = _validPassphrase();
      final recoveryCore = _FakeFirstDeviceRecoveryCore(
        recoveryPublicKey: context.recoveryPublicKey,
      );
      final preparer = E2eeFirstDeviceRecoveryBootstrapPreparer.forTesting(
        recoveryPassphrase: passphrase,
        serviceOrigin: _serviceOrigin,
        encryptedMediaExporter: (media) async => true,
        recoveryCore: recoveryCore,
      );

      preparer.close();
      preparer.close();

      expect(passphrase, everyElement(0));
      await expectLater(
        preparer.prepare(
          accountRootKey: context.ark,
          userId: _userId,
          operationId: _operationId,
          localMember: context.localMember,
        ),
        throwsStateError,
      );
      expect(recoveryCore.closeCount, 0);
    });

    test('恢复句柄关闭失败时不调用 exporter 也不交付 bootstrap', () async {
      final context = await _BootstrapContext.create();
      addTearDown(context.close);
      final passphrase = _validPassphrase();
      final recoveryCore = _FakeFirstDeviceRecoveryCore(
        recoveryPublicKey: context.recoveryPublicKey,
        closeError: StateError('恢复句柄关闭失败'),
      );
      var exporterCalled = false;
      final preparer = E2eeFirstDeviceRecoveryBootstrapPreparer.forTesting(
        recoveryPassphrase: passphrase,
        serviceOrigin: _serviceOrigin,
        encryptedMediaExporter: (media) async {
          exporterCalled = true;
          return true;
        },
        recoveryCore: recoveryCore,
      );

      await expectLater(
        preparer.prepare(
          accountRootKey: context.ark,
          userId: _userId,
          operationId: _operationId,
          localMember: context.localMember,
        ),
        throwsStateError,
      );

      expect(passphrase, everyElement(0));
      expect(recoveryCore.closeCount, 1);
      expect(exporterCalled, isFalse);
    });
  });
}

final class _BootstrapContext {
  const _BootstrapContext({
    required this.ark,
    required this.localMember,
    required this.recoveryPublicKey,
  });

  final KelivoAccountRootKeyHandle ark;
  final E2eeMembershipDeviceInput localMember;
  final Uint8List recoveryPublicKey;

  static Future<_BootstrapContext> create() async {
    const secureCore = KelivoSecureCore();
    final ark = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 1,
    );
    try {
      final localIdentity = await secureCore.generateDeviceIdentity();
      late final E2eeMembershipDeviceInput localMember;
      try {
        final keys = await secureCore.readDevicePublicKeys(localIdentity);
        localMember = E2eeMembershipDeviceInput(
          deviceId: _deviceId,
          keyVersion: 1,
          authGeneration: 0,
          signingPublicKey: keys.signingPublicKey,
          keyAgreementPublicKey: keys.keyAgreementPublicKey,
        );
      } finally {
        await secureCore.closeDeviceIdentity(localIdentity);
      }
      final recoveryIdentity = await secureCore.generateDeviceIdentity();
      late final Uint8List recoveryPublicKey;
      try {
        final keys = await secureCore.readDevicePublicKeys(recoveryIdentity);
        recoveryPublicKey = Uint8List.fromList(keys.keyAgreementPublicKey);
      } finally {
        await secureCore.closeDeviceIdentity(recoveryIdentity);
      }
      return _BootstrapContext(
        ark: ark,
        localMember: localMember,
        recoveryPublicKey: recoveryPublicKey,
      );
    } catch (_) {
      await secureCore.closeAccountRootKey(ark);
      rethrow;
    }
  }

  Future<void> close() => const KelivoSecureCore().closeAccountRootKey(ark);
}

final class _FakeRecoveryIdentity implements E2eeFirstDeviceRecoveryIdentity {
  _FakeRecoveryIdentity(Uint8List publicKey)
    : publicKey = Uint8List.fromList(publicKey).asUnmodifiableView();

  @override
  final Uint8List publicKey;
}

final class _FakeFirstDeviceRecoveryCore
    implements E2eeFirstDeviceRecoveryCore {
  _FakeFirstDeviceRecoveryCore({
    required Uint8List recoveryPublicKey,
    this.closeError,
  }) : _identity = _FakeRecoveryIdentity(recoveryPublicKey);

  final _FakeRecoveryIdentity _identity;
  final Object? closeError;
  final Uint8List capsule = Uint8List.fromList(List<int>.filled(156, 0x63));
  final Uint8List media = Uint8List.fromList(
    List<int>.filled(e2eeEncryptedRecoveryMediaBytes, 0xa7),
  );

  int closeCount = 0;
  Uint8List? initialCapsule;
  Uint8List? genesisManifest;
  Uint8List? serviceOriginSha256;
  Uint8List? validatedPassphrase;

  @override
  void validateRecoveryPassphrase(Uint8List passphrase) {
    validatedPassphrase = Uint8List.fromList(passphrase);
  }

  @override
  Future<E2eeFirstDeviceRecoveryIdentity> generateRecoveryIdentity({
    required String userId,
    required int recoveryPublicKeyVersion,
  }) async {
    expect(userId, _userId);
    expect(recoveryPublicKeyVersion, 1);
    return _identity;
  }

  @override
  Future<Uint8List> sealRecoveryCapsule(
    KelivoAccountRootKeyHandle ark, {
    required int keyEpoch,
    required Uint8List recoveryPublicKey,
    required int recoveryPublicKeyVersion,
    required int capsuleVersion,
  }) async {
    expect(keyEpoch, 1);
    expect(recoveryPublicKey, orderedEquals(_identity.publicKey));
    expect(recoveryPublicKeyVersion, 1);
    expect(capsuleVersion, 1);
    return capsule;
  }

  @override
  Future<Uint8List> exportRecoveryMedia(
    E2eeFirstDeviceRecoveryIdentity recovery,
    KelivoAccountRootKeyHandle initialArk, {
    required Uint8List initialCapsule,
    required Uint8List genesisManifest,
    required Uint8List passphrase,
    required Uint8List serviceOriginSha256,
  }) async {
    expect(recovery, same(_identity));
    this.initialCapsule = Uint8List.fromList(initialCapsule);
    this.genesisManifest = Uint8List.fromList(genesisManifest);
    this.serviceOriginSha256 = Uint8List.fromList(serviceOriginSha256);
    return media;
  }

  @override
  Future<void> closeRecoveryIdentity(
    E2eeFirstDeviceRecoveryIdentity recovery,
  ) async {
    expect(recovery, same(_identity));
    closeCount += 1;
    final error = closeError;
    if (error != null) throw error;
  }
}

E2eeMembershipServerProjection _projection(
  E2eePreparedFirstDeviceSecurityBootstrap prepared,
) {
  final state = prepared.securityState;
  final membership = prepared.membership;
  return E2eeMembershipServerProjection(
    userId: membership.userId,
    securityGeneration: membership.securityGeneration,
    keyEpoch: membership.keyEpoch,
    membershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
    membershipManifest: membership.manifest,
    membershipManifestDigest: membership.digest,
    recoveryPublicKeyVersion: state.recoveryPublicKeyVersion,
    recoveryPublicKey: state.recoveryPublicKey,
    recoveryCapsuleVersion: state.recoveryCapsuleVersion,
    recoveryCapsule: state.recoveryCapsule,
    lastOperationId: state.operationId,
    dataRekeyPhase: E2eeDataRekeyPhase.ready,
  );
}

Uint8List _validPassphrase() =>
    Uint8List.fromList(utf8.encode('correct horse battery staple'));

Uint8List _hexBytes(String value) => Uint8List.fromList(<int>[
  for (var offset = 0; offset < value.length; offset += 2)
    int.parse(value.substring(offset, offset + 2), radix: 16),
]);

Uint8List _rawUuid(String value) {
  final hex = value.replaceAll('-', '');
  return _hexBytes(hex);
}
