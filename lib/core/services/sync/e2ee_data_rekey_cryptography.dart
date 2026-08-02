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

  @override
  final String issuerDeviceId;

  @override
  final int targetKeyEpoch;

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
}
