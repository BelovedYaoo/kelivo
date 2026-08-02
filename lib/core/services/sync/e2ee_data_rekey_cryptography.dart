import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync_types.dart';
import 'e2ee_account_record_cipher.dart';
import 'e2ee_attachment_crypto_session.dart';
import 'e2ee_data_rekey_executor.dart';
import 'e2ee_device_state_access.dart';

final class E2eeDataRekeyCryptographySession
    implements E2eeDataRekeyCryptography {
  factory E2eeDataRekeyCryptographySession({
    required KelivoSecureCore secureCore,
    required E2eeOpenedDeviceStateHandles issuerState,
    required E2eeAccountRecordCipher targetRecordCipher,
    required E2eeAttachmentCrypto targetAttachmentCryptography,
  }) {
    if (targetRecordCipher.currentKeyEpoch !=
        targetAttachmentCryptography.currentKeyEpoch) {
      throw const FormatException('data-rekey 记录与附件目标代次不一致');
    }
    return E2eeDataRekeyCryptographySession._(
      secureCore,
      issuerState.identity,
      targetRecordCipher,
      targetAttachmentCryptography,
      Uuid.unparse(issuerState.binding.deviceId),
      targetRecordCipher.currentKeyEpoch,
    );
  }

  E2eeDataRekeyCryptographySession._(
    this._secureCore,
    this._issuerIdentity,
    this._targetRecordCipher,
    this._targetAttachmentCryptography,
    this.issuerDeviceId,
    this.targetKeyEpoch,
  );

  final KelivoSecureCore _secureCore;
  final KelivoDeviceIdentityHandle _issuerIdentity;
  final E2eeAccountRecordCipher _targetRecordCipher;
  final E2eeAttachmentCrypto _targetAttachmentCryptography;

  bool _targetRecordCipherClosed = false;
  bool _targetAttachmentCryptographyClosed = false;
  Future<void>? _closeFuture;

  @override
  final String issuerDeviceId;

  @override
  final int targetKeyEpoch;

  static Future<E2eeDataRekeyCryptographySession> openTargetState({
    required KelivoSecureCore secureCore,
    required E2eeOpenedDeviceStateHandles issuerState,
    required Uint8List targetStateBlob,
    required String userId,
    required int targetKeyEpoch,
  }) async {
    final sourceAccount = issuerState.binding.account;
    final sourceArk = issuerState.ark;
    if (sourceArk == null ||
        sourceAccount == null ||
        Uuid.unparse(sourceAccount.userId) != userId ||
        !_sameRekeyBytes(sourceArk.userId, sourceAccount.userId)) {
      throw const FormatException('data-rekey 签发设备状态账户绑定不匹配');
    }
    final expectedDeviceId = Uuid.unparse(issuerState.binding.deviceId);
    final issuerPublicKeys = await secureCore.readDevicePublicKeys(
      issuerState.identity,
    );
    KelivoAccountRootKeyHandle? recordArk;
    KelivoAccountRootKeyHandle? manifestArk;
    KelivoAccountRootKeyHandle? chunkArk;
    E2eeAccountRecordCipher? recordCipher;
    E2eeAttachmentCryptoSession? attachmentCryptography;
    try {
      recordArk = await _openTargetAccountRootKey(
        secureCore: secureCore,
        issuerState: issuerState,
        targetStateBlob: targetStateBlob,
        expectedUserId: userId,
        expectedDeviceId: expectedDeviceId,
        expectedDeviceKeyVersion: issuerState.binding.keyVersion,
        expectedTargetKeyEpoch: targetKeyEpoch,
        issuerPublicKeys: issuerPublicKeys,
      );
      manifestArk = await _openTargetAccountRootKey(
        secureCore: secureCore,
        issuerState: issuerState,
        targetStateBlob: targetStateBlob,
        expectedUserId: userId,
        expectedDeviceId: expectedDeviceId,
        expectedDeviceKeyVersion: issuerState.binding.keyVersion,
        expectedTargetKeyEpoch: targetKeyEpoch,
        issuerPublicKeys: issuerPublicKeys,
      );
      chunkArk = await _openTargetAccountRootKey(
        secureCore: secureCore,
        issuerState: issuerState,
        targetStateBlob: targetStateBlob,
        expectedUserId: userId,
        expectedDeviceId: expectedDeviceId,
        expectedDeviceKeyVersion: issuerState.binding.keyVersion,
        expectedTargetKeyEpoch: targetKeyEpoch,
        issuerPublicKeys: issuerPublicKeys,
      );
      recordCipher = E2eeAccountRecordCipher.takeOwnership(
        secureCore: secureCore,
        accountRootKey: recordArk,
        userId: userId,
        currentKeyEpoch: targetKeyEpoch,
      );
      recordArk = null;
      attachmentCryptography = E2eeAttachmentCryptoSession.takeOwnership(
        secureCore: secureCore,
        manifestAccountRootKey: manifestArk,
        chunkAccountRootKey: chunkArk,
        userId: userId,
        currentKeyEpoch: targetKeyEpoch,
      );
      manifestArk = null;
      chunkArk = null;
      return E2eeDataRekeyCryptographySession(
        secureCore: secureCore,
        issuerState: issuerState,
        targetRecordCipher: recordCipher,
        targetAttachmentCryptography: attachmentCryptography,
      );
    } catch (error, stackTrace) {
      await _cleanupTargetCryptographyOpenFailure(
        secureCore: secureCore,
        recordArk: recordArk,
        manifestArk: manifestArk,
        chunkArk: chunkArk,
        recordCipher: recordCipher,
        attachmentCryptography: attachmentCryptography,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<E2eeDataRekeyRewrappedRecord> rewrapRecord(
    CloudSyncDataRekeySourceRecord source,
  ) async {
    final sealed = await _targetRecordCipher.rewrap(
      E2eeUntrustedAccountRecordEnvelope.fromTransport(
        recordId: E2eeUntrustedAccountRecordId.fromTransport(source.recordId),
        envelopeVersion: source.envelopeVersion,
        keyEpoch: source.keyEpoch,
        ciphertext: source.ciphertext,
      ),
    );
    return E2eeDataRekeyRewrappedRecord(
      sourceRecordId: source.recordId,
      sourceRevision: source.revision,
      targetRecordId: sealed.recordId.wireValue,
      targetKeyEpoch: sealed.keyEpoch,
      ciphertext: sealed.ciphertext,
    );
  }

  @override
  Future<E2eeDataRekeyRewrappedAttachmentManifest> rewrapAttachmentManifest(
    CloudSyncDataRekeySourceAttachment source,
  ) async {
    final opened = await _targetAttachmentCryptography.openManifest(
      attachmentId: source.attachmentId,
      uploadId: source.uploadId,
      chunkKeyEpoch: source.chunkKeyEpoch,
      manifestKeyEpoch: source.manifestKeyEpoch,
      manifestRevision: source.manifestRevision,
      ciphertext: source.manifestCiphertext,
    );
    final sealed = await _targetAttachmentCryptography.rewrapManifest(
      source: opened,
      targetManifestRevision: source.manifestRevision + 1,
    );
    return E2eeDataRekeyRewrappedAttachmentManifest(
      attachmentId: sealed.attachmentId,
      uploadId: sealed.uploadId,
      chunkKeyEpoch: sealed.chunkKeyEpoch,
      manifestKeyEpoch: sealed.manifestKeyEpoch,
      manifestRevision: sealed.manifestRevision,
      manifestCiphertext: sealed.ciphertext,
    );
  }

  @override
  Future<Uint8List> signCompletionProof(Uint8List proofFrame) async {
    final signature = await _secureCore.signDataRekeyCompletionProof(
      _issuerIdentity,
      proofFrame: proofFrame,
    );
    return Uint8List.fromList(signature.bytes).asUnmodifiableView();
  }

  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) return existing;
    late final Future<void> closing;
    closing = _closeOwnedCryptography().whenComplete(() {
      if (identical(_closeFuture, closing)) _closeFuture = null;
    });
    _closeFuture = closing;
    return closing;
  }

  Future<void> _closeOwnedCryptography() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    if (!_targetAttachmentCryptographyClosed) {
      try {
        await _targetAttachmentCryptography.close();
        _targetAttachmentCryptographyClosed = true;
      } catch (error, stackTrace) {
        firstError = error;
        firstStackTrace = stackTrace;
      }
    }
    if (!_targetRecordCipherClosed) {
      try {
        await _targetRecordCipher.close();
        _targetRecordCipherClosed = true;
      } catch (error, stackTrace) {
        if (firstError == null) {
          firstError = error;
          firstStackTrace = stackTrace;
        } else {
          developer.log(
            'data-rekey 密码会话关闭时的后续记录密钥清理失败',
            name: 'Kelivo.E2eeDataRekeyCryptographySession',
          );
        }
      }
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }
}

Future<KelivoAccountRootKeyHandle> _openTargetAccountRootKey({
  required KelivoSecureCore secureCore,
  required E2eeOpenedDeviceStateHandles issuerState,
  required Uint8List targetStateBlob,
  required String expectedUserId,
  required String expectedDeviceId,
  required int expectedDeviceKeyVersion,
  required int expectedTargetKeyEpoch,
  required KelivoDevicePublicKeys issuerPublicKeys,
}) async {
  final stateBlob = Uint8List.fromList(targetStateBlob);
  KelivoOpenedDeviceState? opened;
  try {
    opened = await secureCore.openDeviceState(
      issuerState.key,
      stateBlob: stateBlob,
    );
    final account = opened.binding.account;
    final ark = opened.ark;
    if (ark == null ||
        account == null ||
        Uuid.unparse(opened.binding.deviceId) != expectedDeviceId ||
        opened.binding.keyVersion != expectedDeviceKeyVersion ||
        Uuid.unparse(account.userId) != expectedUserId ||
        account.keyEpoch != expectedTargetKeyEpoch) {
      throw const FormatException('data-rekey 目标设备状态绑定不匹配');
    }
    final targetPublicKeys = await secureCore.readDevicePublicKeys(
      opened.identity,
    );
    if (!_sameRekeyBytes(
          targetPublicKeys.signingPublicKey,
          issuerPublicKeys.signingPublicKey,
        ) ||
        !_sameRekeyBytes(
          targetPublicKeys.keyAgreementPublicKey,
          issuerPublicKeys.keyAgreementPublicKey,
        )) {
      throw const FormatException('data-rekey 目标设备身份发生变化');
    }
    await secureCore.closeDeviceIdentity(opened.identity);
    return ark;
  } catch (error, stackTrace) {
    final value = opened;
    if (value != null) {
      await _closeTargetOpenedStateAfterFailure(secureCore, value);
    }
    Error.throwWithStackTrace(error, stackTrace);
  } finally {
    stateBlob.fillRange(0, stateBlob.length, 0);
  }
}

Future<void> _closeTargetOpenedStateAfterFailure(
  KelivoSecureCore secureCore,
  KelivoOpenedDeviceState opened,
) async {
  final cleanup = <Future<void> Function()>[
    if (opened.ark != null) () => secureCore.closeAccountRootKey(opened.ark!),
    () => secureCore.closeDeviceIdentity(opened.identity),
  ];
  for (final action in cleanup) {
    if (!await _retryCryptographyCleanup(action)) {
      developer.log(
        'data-rekey 目标设备状态验证失败后的句柄清理失败',
        name: 'Kelivo.E2eeDataRekeyCryptographySession',
      );
    }
  }
}

Future<void> _cleanupTargetCryptographyOpenFailure({
  required KelivoSecureCore secureCore,
  required KelivoAccountRootKeyHandle? recordArk,
  required KelivoAccountRootKeyHandle? manifestArk,
  required KelivoAccountRootKeyHandle? chunkArk,
  required E2eeAccountRecordCipher? recordCipher,
  required E2eeAttachmentCryptoSession? attachmentCryptography,
}) async {
  final cleanup = <Future<void> Function()>[
    if (attachmentCryptography != null) attachmentCryptography.close,
    if (recordCipher != null) recordCipher.close,
    if (recordArk != null) () => secureCore.closeAccountRootKey(recordArk),
    if (manifestArk != null) () => secureCore.closeAccountRootKey(manifestArk),
    if (chunkArk != null) () => secureCore.closeAccountRootKey(chunkArk),
  ];
  for (final action in cleanup) {
    if (!await _retryCryptographyCleanup(action)) {
      developer.log(
        'data-rekey 密码会话打开失败后的后续句柄清理失败',
        name: 'Kelivo.E2eeDataRekeyCryptographySession',
      );
    }
  }
}

Future<bool> _retryCryptographyCleanup(Future<void> Function() action) async {
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      await action();
      return true;
    } catch (_) {
      // 关闭动作保留失败后的重试能力；重复失败仍按失败关闭处理。
    }
  }
  return false;
}

bool _sameRekeyBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
