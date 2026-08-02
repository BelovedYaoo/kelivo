import 'dart:convert';
import 'dart:typed_data';

import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_trust_manifest.dart';
import 'package:Kelivo/core/services/sync/e2ee_data_rekey_wire.dart';
import 'package:Kelivo/core/services/sync/e2ee_self_revocation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

const _userId = '10000000-0000-4000-8000-000000000001';
const _issuerDeviceId = '20000000-0000-4000-8000-000000000002';
const _requestingDeviceId = '30000000-0000-4000-8000-000000000003';
const _recoveredDeviceId = '40000000-0000-4000-8000-000000000004';
const _unknownDeviceId = '50000000-0000-4000-8000-000000000005';
const _initializeOperationId = '60000000-0000-4000-8000-000000000006';
const _pairingOperationId = '70000000-0000-4000-8000-000000000007';
const _mutationId = '80000000-0000-4000-8000-000000000008';
const _rotationOperationId = '90000000-0000-4000-8000-000000000009';
const _resumeOperationId = 'a0000000-0000-4000-8000-00000000000a';
final _requestedAt = DateTime.utc(2026, 8, 2, 10);
final _expiresAt = _requestedAt.add(const Duration(hours: 1));
final _receiptExpiresAt = _requestedAt.add(const Duration(days: 30));
final _intentDigest = _filled(32, 0x31);
final _otherIntentDigest = _filled(32, 0x32);
final _intentSignature = _filled(64, 0x41);

void main() {
  late _SelfRevocationFixture fixture;

  setUpAll(() async {
    fixture = await _SelfRevocationFixture.create();
  });

  tearDownAll(() => fixture.close());

  test('待协调列表仅在本地可信头和请求设备公钥验签后升级为可信意图', () async {
    final verifier = _ExpectedIntentVerifier(fixture);
    final coordinator = E2eeTrustedSelfRevocationCoordinator(
      intentVerifier: verifier,
    );

    final verified = await coordinator.verifyPendingRequestList(
      trustedCurrentHead: fixture.trustedCurrentHead,
      untrustedList: _pendingList(fixture),
      now: _requestedAt.add(const Duration(minutes: 1)),
    );

    expect(verified, hasLength(1));
    expect(verified.single.userId, _userId);
    expect(verified.single.deviceId, _requestingDeviceId);
    expect(verified.single.operationId, _rotationOperationId);
    expect(verified.single.intentDigest, orderedEquals(_intentDigest));
    final rotationBinding = verified.single.toRotationBinding();
    expect(rotationBinding.deviceId, _requestingDeviceId);
    expect(rotationBinding.mutationId, _mutationId);
    expect(rotationBinding.operationId, _rotationOperationId);
    expect(
      rotationBinding.expectedGeneration,
      fixture.trustedCurrentHead.securityGeneration,
    );
    expect(
      rotationBinding.expectedKeyEpoch,
      fixture.trustedCurrentHead.keyEpoch,
    );
    expect(
      rotationBinding.expectedMembershipManifestDigest,
      orderedEquals(fixture.trustedCurrentHead.digest),
    );
    expect(rotationBinding.intentDigest, orderedEquals(_intentDigest));
    expect(verifier.calls, 1);
  });

  test('待协调列表拒绝不匹配本地可信头或未知请求设备', () async {
    final coordinator = E2eeTrustedSelfRevocationCoordinator(
      intentVerifier: _ExpectedIntentVerifier(fixture),
    );

    await expectLater(
      coordinator.verifyPendingRequestList(
        trustedCurrentHead: fixture.trustedCurrentHead,
        untrustedList: _pendingList(
          fixture,
          expectedGeneration: fixture.trustedCurrentHead.securityGeneration - 1,
        ),
        now: _requestedAt,
      ),
      _failsWith(
        E2eeSelfRevocationVerificationFailure.currentSecurityHeadMismatch,
      ),
    );
    await expectLater(
      coordinator.verifyPendingRequestList(
        trustedCurrentHead: fixture.trustedCurrentHead,
        untrustedList: _pendingList(fixture, deviceId: _unknownDeviceId),
        now: _requestedAt,
      ),
      _failsWith(
        E2eeSelfRevocationVerificationFailure.requestingDeviceNotTrusted,
      ),
    );
  });

  test('待协调列表按本地时间拒绝到期边界且不信任服务端 intentDigest', () async {
    final coordinator = E2eeTrustedSelfRevocationCoordinator(
      intentVerifier: _ExpectedIntentVerifier(fixture),
    );
    final parsedBeforeExpiry = _pendingList(fixture, parserNow: _requestedAt);

    await expectLater(
      coordinator.verifyPendingRequestList(
        trustedCurrentHead: fixture.trustedCurrentHead,
        untrustedList: parsedBeforeExpiry,
        now: _expiresAt,
      ),
      _failsWith(E2eeSelfRevocationVerificationFailure.intentExpired),
    );
    await expectLater(
      coordinator.verifyPendingRequestList(
        trustedCurrentHead: fixture.trustedCurrentHead,
        untrustedList: _pendingList(fixture, intentDigest: _otherIntentDigest),
        now: _requestedAt,
      ),
      _failsWith(E2eeSelfRevocationVerificationFailure.intentInvalid),
    );
  });

  test('确认回执验证轮换、恢复接续、最终签发者及完成证明', () async {
    final coordinator = E2eeTrustedSelfRevocationCoordinator(
      intentVerifier: _ExpectedIntentVerifier(fixture),
    );
    final confirmed = await fixture.buildConfirmed();

    final verified = await coordinator.verifyConfirmedReceipt(
      trustedCurrentHead: fixture.trustedCurrentHead,
      untrustedConfirmed: confirmed,
    );

    expect(verified.securityStates, hasLength(2));
    expect(
      verified.securityStates.first.operationKind,
      E2eeMembershipOperationKind.revokeRotate,
    );
    expect(
      verified.finalSecurityHead.operationKind,
      E2eeMembershipOperationKind.recoverResume,
    );
    expect(verified.finalSecurityHead.issuerDeviceId, _recoveredDeviceId);
    expect(verified.completion.issuerDeviceId, _recoveredDeviceId);
  });

  test('确认回执拒绝未绑定自撤销摘要的轮换和伪恢复接续', () async {
    final coordinator = E2eeTrustedSelfRevocationCoordinator(
      intentVerifier: _ExpectedIntentVerifier(fixture),
    );

    await expectLater(
      coordinator.verifyConfirmedReceipt(
        trustedCurrentHead: fixture.trustedCurrentHead,
        untrustedConfirmed: await fixture.buildConfirmed(
          rotationAuthorizationDigest: _otherIntentDigest,
        ),
      ),
      _failsWith(E2eeSelfRevocationVerificationFailure.receiptLineageInvalid),
    );
    await expectLater(
      coordinator.verifyConfirmedReceipt(
        trustedCurrentHead: fixture.trustedCurrentHead,
        untrustedConfirmed: await fixture.buildConfirmed(
          useAddDeviceInsteadOfResume: true,
        ),
      ),
      _failsWith(E2eeSelfRevocationVerificationFailure.receiptLineageInvalid),
    );
  });

  test('确认回执拒绝非最终签发者和无效 completion 签名', () async {
    final coordinator = E2eeTrustedSelfRevocationCoordinator(
      intentVerifier: _ExpectedIntentVerifier(fixture),
    );

    await expectLater(
      coordinator.verifyConfirmedReceipt(
        trustedCurrentHead: fixture.trustedCurrentHead,
        untrustedConfirmed: await fixture.buildConfirmed(
          completionIssuerDeviceId: _issuerDeviceId,
        ),
      ),
      _failsWith(E2eeSelfRevocationVerificationFailure.completionInvalid),
    );
    await expectLater(
      coordinator.verifyConfirmedReceipt(
        trustedCurrentHead: fixture.trustedCurrentHead,
        untrustedConfirmed: await fixture.buildConfirmed(
          tamperCompletionSignature: true,
        ),
      ),
      _failsWith(E2eeSelfRevocationVerificationFailure.completionInvalid),
    );
  });
}

Matcher _failsWith(E2eeSelfRevocationVerificationFailure failure) {
  return throwsA(
    isA<E2eeSelfRevocationVerificationException>().having(
      (error) => error.failure,
      'failure',
      failure,
    ),
  );
}

CloudSyncUntrustedSelfRevocationRequestList _pendingList(
  _SelfRevocationFixture fixture, {
  String deviceId = _requestingDeviceId,
  int? expectedGeneration,
  Uint8List? intentDigest,
  DateTime? parserNow,
}) {
  return CloudSyncUntrustedSelfRevocationRequestList.fromJson(<String, Object?>{
    'requests': <Object?>[
      <String, Object?>{
        'deviceId': deviceId,
        'deviceName': '服务端元数据名称',
        'mutationId': _mutationId,
        'operationId': _rotationOperationId,
        'expectedGeneration':
            expectedGeneration ?? fixture.trustedCurrentHead.securityGeneration,
        'expectedKeyEpoch': fixture.trustedCurrentHead.keyEpoch,
        'expectedMembershipManifestDigest': _encoded(
          fixture.trustedCurrentHead.digest,
        ),
        'intentDigest': _encoded(intentDigest ?? _intentDigest),
        'intentSignature': _encoded(_intentSignature),
        'requestedAt': _requestedAt.toIso8601String(),
        'expiresAt': _expiresAt.toIso8601String(),
      },
    ],
  }, now: parserNow ?? _requestedAt);
}

final class _ExpectedIntentVerifier
    implements E2eeSelfRevocationIntentVerifier {
  _ExpectedIntentVerifier(this.fixture);

  final _SelfRevocationFixture fixture;
  int calls = 0;

  @override
  Future<Uint8List> verifyAndDigest({
    required String userId,
    required String deviceId,
    required String mutationId,
    required String operationId,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required Uint8List expectedMembershipManifestDigest,
    required DateTime expiresAt,
    required Uint8List signature,
    required Uint8List signingPublicKey,
  }) async {
    calls += 1;
    if (userId != _userId ||
        deviceId != _requestingDeviceId ||
        mutationId != _mutationId ||
        operationId != _rotationOperationId ||
        expectedGeneration != fixture.trustedCurrentHead.securityGeneration ||
        expectedKeyEpoch != fixture.trustedCurrentHead.keyEpoch ||
        !_sameBytes(
          expectedMembershipManifestDigest,
          fixture.trustedCurrentHead.digest,
        ) ||
        expiresAt != _expiresAt ||
        !_sameBytes(signature, _intentSignature) ||
        !_sameBytes(
          signingPublicKey,
          fixture.requestingDevice.signingPublicKey,
        )) {
      throw StateError('协调器传入 native intent 验签的绑定字段不完整');
    }
    return Uint8List.fromList(_intentDigest);
  }
}

final class _SelfRevocationFixture {
  const _SelfRevocationFixture({
    required this.secureCore,
    required this.ark,
    required this.issuerIdentity,
    required this.requestingIdentity,
    required this.recoveredIdentity,
    required this.issuerDevice,
    required this.requestingDevice,
    required this.recoveredDevice,
    required this.trustedCurrentHead,
    required this.recoveryCapsule2,
  });

  final KelivoSecureCore secureCore;
  final KelivoAccountRootKeyHandle ark;
  final KelivoDeviceIdentityHandle issuerIdentity;
  final KelivoDeviceIdentityHandle requestingIdentity;
  final KelivoDeviceIdentityHandle recoveredIdentity;
  final E2eeMembershipDeviceInput issuerDevice;
  final E2eeMembershipDeviceInput requestingDevice;
  final E2eeMembershipDeviceInput recoveredDevice;
  final E2eeVerifiedMembership trustedCurrentHead;
  final Uint8List recoveryCapsule2;

  static Future<_SelfRevocationFixture> create() async {
    const secureCore = KelivoSecureCore();
    const manifestModule = E2eeAccountTrustManifestModule();
    final identities = <KelivoDeviceIdentityHandle>[];
    KelivoAccountRootKeyHandle? ark;
    try {
      ark = await secureCore.generateAccountRootKey(
        userId: _rawUuid(_userId),
        keyEpoch: 1,
      );
      final issuer = await _newDevice(
        secureCore,
        deviceId: _issuerDeviceId,
        authGeneration: 0,
      );
      identities.add(issuer.$1);
      final requesting = await _newDevice(
        secureCore,
        deviceId: _requestingDeviceId,
        authGeneration: 1,
      );
      identities.add(requesting.$1);
      final recovered = await _newDevice(
        secureCore,
        deviceId: _recoveredDeviceId,
        authGeneration: 1,
      );
      identities.add(recovered.$1);
      final recoveryIdentity = await secureCore.generateDeviceIdentity();
      late final Uint8List recoveryPublicKey;
      try {
        final keys = await secureCore.readDevicePublicKeys(recoveryIdentity);
        recoveryPublicKey = Uint8List.fromList(keys.keyAgreementPublicKey);
      } finally {
        await secureCore.closeDeviceIdentity(recoveryIdentity);
      }
      final recoveryCapsule1 = _filled(80, 0x51);
      final recoveryCapsule2 = _filled(80, 0x52);
      final initialized = await manifestModule.create(
        ark: ark,
        change: E2eeInitializeMembershipChange(
          userId: _userId,
          operationId: _initializeOperationId,
          member: issuer.$2,
          recoveryPublicKeyVersion: 1,
          recoveryPublicKey: recoveryPublicKey,
          recoveryCapsuleVersion: 1,
          recoveryCapsule: recoveryCapsule1,
        ),
      );
      final paired = await manifestModule.create(
        ark: ark,
        change: E2eeAddDeviceMembershipChange(
          previous: initialized,
          pairingId: _pairingOperationId,
          issuerDeviceId: _issuerDeviceId,
          subject: requesting.$2,
        ),
      );
      final epoch2 = await secureCore.generateAccountRootKey(
        userId: _rawUuid(_userId),
        keyEpoch: 2,
      );
      try {
        await secureCore.addAccountRootKeyEpoch(ark, source: epoch2);
      } finally {
        await secureCore.closeAccountRootKey(epoch2);
      }
      return _SelfRevocationFixture(
        secureCore: secureCore,
        ark: ark,
        issuerIdentity: issuer.$1,
        requestingIdentity: requesting.$1,
        recoveredIdentity: recovered.$1,
        issuerDevice: issuer.$2,
        requestingDevice: requesting.$2,
        recoveredDevice: recovered.$2,
        trustedCurrentHead: paired,
        recoveryCapsule2: recoveryCapsule2,
      );
    } catch (_) {
      for (final identity in identities.reversed) {
        await secureCore.closeDeviceIdentity(identity);
      }
      if (ark != null) await secureCore.closeAccountRootKey(ark);
      rethrow;
    }
  }

  Future<CloudSyncUntrustedSelfRevocationConfirmed> buildConfirmed({
    Uint8List? rotationAuthorizationDigest,
    bool useAddDeviceInsteadOfResume = false,
    String? completionIssuerDeviceId,
    bool tamperCompletionSignature = false,
  }) async {
    const manifestModule = E2eeAccountTrustManifestModule();
    final rotated = await manifestModule.create(
      ark: ark,
      change: E2eeRevokeRotateMembershipChange(
        previous: trustedCurrentHead,
        operationId: _rotationOperationId,
        issuerDeviceId: _issuerDeviceId,
        revokedDeviceId: _requestingDeviceId,
        nextRecoveryCapsuleVersion: 2,
        nextRecoveryCapsule: recoveryCapsule2,
        operationAuthorizationDigest:
            rotationAuthorizationDigest ?? _intentDigest,
      ),
    );
    final resumed = useAddDeviceInsteadOfResume
        ? await manifestModule.create(
            ark: ark,
            change: E2eeAddDeviceMembershipChange(
              previous: rotated,
              pairingId: _resumeOperationId,
              issuerDeviceId: _issuerDeviceId,
              subject: recoveredDevice,
            ),
          )
        : await manifestModule.create(
            ark: ark,
            change: E2eeRecoverResumeMembershipChange(
              previous: rotated,
              operationId: _resumeOperationId,
              subject: recoveredDevice,
            ),
          );
    final issuerId = completionIssuerDeviceId ?? resumed.issuerDeviceId;
    final signer = switch (issuerId) {
      _issuerDeviceId => issuerIdentity,
      _recoveredDeviceId => recoveredIdentity,
      _ => throw StateError('测试 completion 签发设备无效'),
    };
    final completion = await _completionJson(
      secureCore: secureCore,
      signer: signer,
      issuerDeviceId: issuerId,
      finalMembership: resumed,
      tamperSignature: tamperCompletionSignature,
    );
    final request = CloudSyncSelfRevocationRequest(
      deviceId: _requestingDeviceId,
      mutationId: _mutationId,
      operationId: _rotationOperationId,
      expectedGeneration: trustedCurrentHead.securityGeneration,
      expectedKeyEpoch: trustedCurrentHead.keyEpoch,
      expectedMembershipManifestDigest: CloudSyncMembershipManifestDigest.parse(
        _encoded(trustedCurrentHead.digest),
      ),
      expiresAt: _expiresAt,
      continuationToken: CloudSyncSelfRevocationContinuationToken.generate(),
      intentDigest: _intentDigest,
      intentSignature: _intentSignature,
    );
    final common = <String, Object?>{
      'deviceId': _requestingDeviceId,
      'mutationId': _mutationId,
      'operationId': _rotationOperationId,
      'expectedGeneration': trustedCurrentHead.securityGeneration,
      'expectedKeyEpoch': trustedCurrentHead.keyEpoch,
      'expectedMembershipManifestDigest': _encoded(trustedCurrentHead.digest),
      'intentDigest': _encoded(_intentDigest),
      'intentSignature': _encoded(_intentSignature),
      'requestedAt': _requestedAt.toIso8601String(),
      'expiresAt': _expiresAt.toIso8601String(),
      'receiptExpiresAt': _receiptExpiresAt.toIso8601String(),
    };
    final requestResult = CloudSyncSelfRevocationRequestResult.fromJson(
      <String, Object?>{'result': 'requested', 'status': 'pending', ...common},
      request: request,
    );
    final status = CloudSyncSelfRevocationStatus.fromJson(<String, Object?>{
      'status': 'confirmed',
      ...common,
      'receipt': <String, Object?>{
        'securityStates': <Object?>[
          _securityStateJson(
            rotated,
            recoveryCapsule: recoveryCapsule2,
            committedAt: _requestedAt.add(const Duration(minutes: 2)),
          ),
          _securityStateJson(
            resumed,
            recoveryCapsule: recoveryCapsule2,
            committedAt: _requestedAt.add(const Duration(minutes: 3)),
          ),
        ],
        'completion': completion,
      },
    }, request: requestResult);
    if (status is! CloudSyncUntrustedSelfRevocationConfirmed) {
      throw StateError('测试回执未解析为 confirmed');
    }
    return status;
  }

  Future<void> close() async {
    await secureCore.closeDeviceIdentity(recoveredIdentity);
    await secureCore.closeDeviceIdentity(requestingIdentity);
    await secureCore.closeDeviceIdentity(issuerIdentity);
    await secureCore.closeAccountRootKey(ark);
  }
}

Future<(KelivoDeviceIdentityHandle, E2eeMembershipDeviceInput)> _newDevice(
  KelivoSecureCore secureCore, {
  required String deviceId,
  required int authGeneration,
}) async {
  final identity = await secureCore.generateDeviceIdentity();
  try {
    final keys = await secureCore.readDevicePublicKeys(identity);
    return (
      identity,
      E2eeMembershipDeviceInput(
        deviceId: deviceId,
        keyVersion: 1,
        authGeneration: authGeneration,
        signingPublicKey: keys.signingPublicKey,
        keyAgreementPublicKey: keys.keyAgreementPublicKey,
      ),
    );
  } catch (_) {
    await secureCore.closeDeviceIdentity(identity);
    rethrow;
  }
}

Map<String, Object?> _securityStateJson(
  E2eeVerifiedMembership membership, {
  required Uint8List recoveryCapsule,
  required DateTime committedAt,
}) {
  return <String, Object?>{
    'generation': membership.securityGeneration,
    'keyEpoch': membership.keyEpoch,
    'membershipManifest': _encoded(membership.manifest),
    'membershipManifestDigest': _encoded(membership.digest),
    'recoveryPublicKeyVersion': membership.recoveryPublicKeyVersion,
    'recoveryPublicKey': _encoded(membership.recoveryPublicKey),
    'recoveryCapsuleVersion': membership.recoveryCapsuleVersion,
    'recoveryCapsule': _encoded(recoveryCapsule),
    'operationId': membership.operationId,
    'committedAt': committedAt.toIso8601String(),
  };
}

Future<Map<String, Object?>> _completionJson({
  required KelivoSecureCore secureCore,
  required KelivoDeviceIdentityHandle signer,
  required String issuerDeviceId,
  required E2eeVerifiedMembership finalMembership,
  required bool tamperSignature,
}) async {
  final sourceSnapshotRoot = _filled(32, 0x61);
  final stagedCiphertextSetDigest = _filled(32, 0x62);
  final frame = buildE2eeDataRekeyCompletionFrame(
    E2eeDataRekeyCompletionFields(
      operationId: _rotationOperationId,
      userId: _userId,
      issuerDeviceId: issuerDeviceId,
      sourceDataGeneration: 7,
      targetDataGeneration: 8,
      sourceKeyEpoch: 1,
      targetKeyEpoch: 2,
      sourceSnapshotRoot: sourceSnapshotRoot,
      sourceRecordCount: 0,
      sourceAttachmentCount: 0,
      sourceMaximumChangeSeq: 0,
      sourceRecordCursorEnd: null,
      sourceAttachmentCursorEnd: null,
      membershipGeneration: finalMembership.securityGeneration,
      membershipManifestDigest: finalMembership.digest,
      stagedRecordCount: 0,
      stagedAttachmentCount: 0,
      stagedCiphertextSetDigest: stagedCiphertextSetDigest,
    ),
  );
  final signed = await secureCore.signDataRekeyCompletionProof(
    signer,
    proofFrame: frame,
  );
  final signature = Uint8List.fromList(signed.bytes);
  if (tamperSignature) signature[0] ^= 1;
  final proofDigest = digestE2eeDataRekeyCompletionProof(
    proofFrame: frame,
    signature: signature,
  );
  return <String, Object?>{
    'proofVersion': 2,
    'operationId': _rotationOperationId,
    'issuerDeviceId': issuerDeviceId,
    'sourceDataGeneration': 7,
    'targetDataGeneration': 8,
    'sourceKeyEpoch': 1,
    'targetKeyEpoch': 2,
    'sourceSnapshotRoot': _encoded(sourceSnapshotRoot),
    'sourceRecordCount': 0,
    'sourceAttachmentCount': 0,
    'sourceMaximumChangeSeq': 0,
    'sourceRecordCursorEnd': null,
    'sourceAttachmentCursorEnd': null,
    'membershipGeneration': finalMembership.securityGeneration,
    'membershipManifestDigest': _encoded(finalMembership.digest),
    'stagedRecordCount': 0,
    'stagedAttachmentCount': 0,
    'stagedCiphertextSetDigest': _encoded(stagedCiphertextSetDigest),
    'proofFrame': _encoded(frame),
    'proofDigest': _encoded(proofDigest),
    'signature': _encoded(signature),
    'finalizedAt': _requestedAt
        .add(const Duration(minutes: 4))
        .toIso8601String(),
  };
}

Uint8List _rawUuid(String value) {
  final hex = value.replaceAll('-', '');
  return Uint8List.fromList(<int>[
    for (var offset = 0; offset < hex.length; offset += 2)
      int.parse(hex.substring(offset, offset + 2), radix: 16),
  ]);
}

Uint8List _filled(int length, int value) =>
    Uint8List.fromList(List<int>.filled(length, value));

String _encoded(Uint8List value) => base64Url.encode(value).replaceAll('=', '');

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
