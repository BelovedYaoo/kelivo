import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_authenticator.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_recovery.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_attachment_types.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_pairing_qr_codec.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_record_types.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_key_lease.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_cipher.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_trust_manifest.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_crypto_session.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_file_store.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_manifest.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_upload_coordinator.dart';
import 'package:Kelivo/core/services/sync/e2ee_device_state_access.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_state.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_execution_budget.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_payload_codec.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:Kelivo/utils/app_directories.dart';

import '../../database/test_database_cipher.dart';
import '../../../support/secure_core_test_store.dart';

const _mutationId1 = '00000000-0000-4000-8000-000000000001';
const _mutationId2 = '00000000-0000-4000-8000-000000000002';
const _mutationId3 = '00000000-0000-4000-8000-000000000003';
const _mutationId4 = '00000000-0000-4000-8000-000000000004';
const _mutationId5 = '00000000-0000-4000-8000-000000000005';
const _mutationId6 = '00000000-0000-4000-8000-000000000006';
const _mutationId7 = '00000000-0000-4000-8000-000000000007';
const _recordId1 = '10000000-0000-4000-8000-000000000001';
const _recordId2 = '10000000-0000-4000-8000-000000000002';
const _deviceId1 = '20000000-0000-4000-8000-000000000001';
const _deviceId2 = '20000000-0000-4000-8000-000000000002';
const _deviceId3 = '20000000-0000-4000-8000-000000000003';
const _deviceId4 = '20000000-0000-4000-8000-000000000004';
const _deviceId5 = '20000000-0000-4000-8000-000000000005';
const _attemptId1 = '30000000-0000-4000-8000-000000000001';
const _attemptId2 = '30000000-0000-4000-8000-000000000002';
const _userId = '40000000-0000-4000-8000-000000000001';
const _accountContextId = '50000000-0000-4000-8000-000000000001';
const _pairingId = '60000000-0000-4000-8000-000000000001';
const _issuerDeviceId = '70000000-0000-4000-8000-000000000001';
const _attachmentId = '80000000-0000-4000-8000-000000000001';
const _uploadId = '90000000-0000-4000-8000-000000000001';
const _fullTokenValue = 'kelivo_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _otherFullTokenValue =
    'kelivo_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const _onboardingTokenValue =
    'kelivo_onboarding_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

final _fullToken = CloudSyncFullSessionToken.parse(_fullTokenValue);
final _otherFullToken = CloudSyncFullSessionToken.parse(_otherFullTokenValue);
final _onboardingToken = CloudSyncOnboardingToken.parse(_onboardingTokenValue);

Map<String, Object?> _validConversationPayload() => <String, Object?>{
  'title': '会话',
  'createdAt': '2026-07-28T00:00:00.000Z',
  'updatedAt': '2026-07-28T00:00:01.000Z',
  'isPinned': false,
  'assistantId': null,
  'mcpServerIds': const <Object?>['mcp-1'],
  'truncateIndex': -1,
  'summary': null,
  'lastSummarizedMessageCount': 0,
  'chatSuggestions': const <Object?>['继续'],
};

Map<String, Object?> _validTurnPayload() => <String, Object?>{
  'conversationId': 'conversation-1',
  'createdAt': '2026-07-28T00:00:00.000Z',
};

Map<String, Object?> _validMessagePayload() => <String, Object?>{
  'conversationId': 'conversation-1',
  'turnId': 'turn-1',
  'role': 'assistant',
  'content': '完成',
  'attachments': const <Object?>[],
  'timestamp': '2026-07-28T00:00:01.000Z',
  'groupId': 'group-1',
  'version': 0,
  'status': 'completed',
  'modelId': null,
  'providerId': null,
  'totalTokens': 1,
  'reasoningText': null,
  'reasoningSegmentsJson': null,
  'translation': null,
  'reasoningStartAt': null,
  'reasoningFinishedAt': null,
  'promptTokens': 1,
  'completionTokens': 0,
  'cachedTokens': 0,
  'durationMs': 1,
};

Map<String, Object?> _validMessageAttachment(int index) {
  final suffix = (index + 1).toRadixString(16).padLeft(12, '0');
  return <String, Object?>{
    'attachmentId': '80000000-0000-4000-8000-$suffix',
    'uploadId': '90000000-0000-4000-8000-$suffix',
    'keyEpoch': 7,
    'kind': index.isEven ? 'image' : 'file',
    'order': index,
  };
}

final class _LengthOnlyAttachments extends ListBase<Object?> {
  @override
  int get length => e2eeSyncMaximumMessageAttachmentCount + 1;

  @override
  set length(int value) => throw UnsupportedError('只用于验证附件数量前置门禁');

  @override
  Object? operator [](int index) => throw StateError('超限附件不应被读取');

  @override
  void operator []=(int index, Object? value) {
    throw UnsupportedError('只用于验证附件数量前置门禁');
  }
}

Map<String, Object?> _validMessageSelectionPayload() => <String, Object?>{
  'conversationId': 'conversation-1',
  'groupId': 'group-1',
  'selectedVersion': 0,
};

Map<String, Object?> _validToolEventPayload({Object? value = true}) =>
    <String, Object?>{
      'messageId': 'message-1',
      'events': <Object?>[
        <String, Object?>{'value': value},
      ],
    };

Map<String, Object?> _validThoughtSignaturePayload() => <String, Object?>{
  'messageId': 'message-1',
  'signature': 'signature',
};

Uint8List _filledBytes(int length, [int value = 0]) {
  return Uint8List.fromList(List<int>.filled(length, value));
}

String _encodedBytes(int length, [int value = 0]) {
  return base64Url.encode(_filledBytes(length, value)).replaceAll('=', '');
}

String _encodedData(Uint8List value) {
  return base64Url.encode(value).replaceAll('=', '');
}

Uint8List _sha256Bytes(Uint8List value) {
  return Uint8List.fromList(sha256.convert(value).bytes);
}

String _encodedSha256(Uint8List value) {
  return _encodedData(_sha256Bytes(value));
}

String _encodedRecordCiphertext(E2eeSealedAccountRecordEnvelope record) {
  return base64Url.encode(record.ciphertext).replaceAll('=', '');
}

E2eeUntrustedAccountRecordEnvelope _untrustedRecord(
  E2eeSealedAccountRecordEnvelope record, {
  E2eeUntrustedAccountRecordId? recordId,
  int? keyEpoch,
  Uint8List? ciphertext,
}) {
  return E2eeUntrustedAccountRecordEnvelope.fromTransport(
    recordId:
        recordId ??
        E2eeUntrustedAccountRecordId.fromTransport(record.recordId.wireValue),
    envelopeVersion: e2eeAccountRecordEnvelopeVersion,
    keyEpoch: keyEpoch ?? record.keyEpoch,
    ciphertext: ciphertext ?? record.ciphertext,
  );
}

Future<E2eeUntrustedAccountRecordEnvelope> _sealRawAccountRecord({
  required KelivoSecureCore core,
  required KelivoAccountRootKeyHandle ark,
  required SyncEntityKey recordIdKey,
  required SyncEntityKey frameKey,
  required String userId,
  int keyEpoch = 7,
}) async {
  final canonicalKey = _recordCanonicalKey(recordIdKey);
  final frame = _recordPlaintextFrame(frameKey, Uint8List(0));
  final associatedData = _recordAssociatedData(userId);
  Uint8List? ciphertext;
  try {
    final recordId = await core.deriveAccountRecordId(
      ark,
      keyEpoch: keyEpoch,
      canonicalEntityKey: canonicalKey,
    );
    ciphertext = await core.sealAccountRecord(
      ark,
      recordId: recordId,
      keyEpoch: keyEpoch,
      associatedData: associatedData,
      plaintext: frame,
    );
    return E2eeUntrustedAccountRecordEnvelope.fromTransport(
      recordId: E2eeUntrustedAccountRecordId.fromTransport(
        _uuidStringForTest(recordId),
      ),
      envelopeVersion: e2eeAccountRecordEnvelopeVersion,
      keyEpoch: keyEpoch,
      ciphertext: ciphertext,
    );
  } finally {
    canonicalKey.fillRange(0, canonicalKey.length, 0);
    frame.fillRange(0, frame.length, 0);
    associatedData.fillRange(0, associatedData.length, 0);
    ciphertext?.fillRange(0, ciphertext.length, 0);
  }
}

Uint8List _recordCanonicalKey(SyncEntityKey key) {
  final typeBytes = utf8.encode(key.entityType);
  final idBytes = utf8.encode(key.entityId);
  final result = Uint8List(20 + typeBytes.length + idBytes.length);
  result.setRange(0, 8, ascii.encode('KELVRK01'));
  final fields = ByteData.sublistView(result);
  fields.setUint16(8, 1, Endian.big);
  fields.setUint32(12, typeBytes.length, Endian.big);
  fields.setUint32(16, idBytes.length, Endian.big);
  result.setRange(20, 20 + typeBytes.length, typeBytes);
  result.setRange(20 + typeBytes.length, result.length, idBytes);
  return result;
}

Uint8List _recordPlaintextFrame(SyncEntityKey key, Uint8List payload) {
  final typeBytes = utf8.encode(key.entityType);
  final idBytes = utf8.encode(key.entityId);
  final result = Uint8List(
    24 + typeBytes.length + idBytes.length + payload.length,
  );
  result.setRange(0, 8, ascii.encode('KELVRF01'));
  final fields = ByteData.sublistView(result);
  fields.setUint16(8, 1, Endian.big);
  fields.setUint32(12, typeBytes.length, Endian.big);
  fields.setUint32(16, idBytes.length, Endian.big);
  fields.setUint32(20, payload.length, Endian.big);
  result.setRange(24, 24 + typeBytes.length, typeBytes);
  result.setRange(
    24 + typeBytes.length,
    24 + typeBytes.length + idBytes.length,
    idBytes,
  );
  result.setRange(
    24 + typeBytes.length + idBytes.length,
    result.length,
    payload,
  );
  return result;
}

Uint8List _recordAssociatedData(String userId) {
  final result = Uint8List(28);
  result.setRange(0, 8, ascii.encode('KELVRA01'));
  final fields = ByteData.sublistView(result);
  fields.setUint16(8, 1, Endian.big);
  fields.setUint16(10, e2eeAccountRecordSyncProtocolVersion, Endian.big);
  result.setRange(12, 28, _rawUuid(userId));
  return result;
}

CloudSyncOpaqueDeviceIdentity _deviceIdentity() {
  return CloudSyncOpaqueDeviceIdentity(
    deviceId: _deviceId1,
    deviceName: 'Windows 主机',
    platform: CloudSyncPlatform.windows,
    clientVersion: '1.2.3',
    deviceKeyVersion: 1,
    signingPublicKey: _filledBytes(cloudSyncDevicePublicKeyBytes, 1),
    keyAgreementPublicKey: _filledBytes(cloudSyncDevicePublicKeyBytes, 2),
  );
}

Map<String, Object?> _authenticatedData({
  String token = _fullTokenValue,
  int keyEpoch = 7,
  String deviceId = _deviceId1,
  String loginName = 'alice',
}) {
  return <String, Object?>{
    'protocolVersion': cloudSyncOpaqueProtocolVersion,
    'result': 'authenticated',
    'keyEpoch': keyEpoch,
    'token': token,
    'tokenExpiresAt': '2026-07-27T05:00:00.000Z',
    'user': <String, Object?>{
      'id': _userId,
      'loginName': loginName,
      'displayName': 'Alice',
      'role': 'owner',
      'attachmentQuotaBytes': 1048576,
    },
    'device': <String, Object?>{
      'id': deviceId,
      'name': 'Windows 主机',
      'platform': 'windows',
      'clientVersion': '1.2.3',
      'authGeneration': 0,
      'sessionGeneration': 1,
      'status': 'active',
      'createdAt': '2026-07-26T05:00:00.000Z',
    },
  };
}

CloudSyncGenesisSecurityState _genesisSecurityState() {
  final manifest = _filledBytes(cloudSyncMembershipManifestMinimumBytes, 30);
  return CloudSyncGenesisSecurityState(
    operationId: _attemptId1,
    membershipManifest: manifest,
    membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
      Uint8List.fromList(sha256.convert(manifest).bytes),
    ),
    recoveryPublicKeyVersion: 1,
    recoveryPublicKey: _filledBytes(cloudSyncRecoveryPublicKeyBytes, 31),
    recoveryCapsuleVersion: 1,
    recoveryCapsule: _filledBytes(cloudSyncRecoveryCapsuleBytes, 32),
  );
}

Map<String, Object?> _registrationSecurityStateData({
  String deviceId = _deviceId1,
  CloudSyncGenesisSecurityState? securityState,
  Uint8List? accountKeyEnvelope,
}) {
  final genesis = securityState ?? _genesisSecurityState();
  return <String, Object?>{
    'generation': 1,
    'keyEpoch': 1,
    'dataRekeyPhase': 'ready',
    'membershipManifest': _encodedData(genesis.membershipManifest),
    'membershipManifestDigest': genesis.membershipManifestDigest.encoded,
    'recoveryPublicKeyVersion': genesis.recoveryPublicKeyVersion,
    'recoveryPublicKey': _encodedData(genesis.recoveryPublicKey),
    'recoveryCapsuleVersion': genesis.recoveryCapsuleVersion,
    'recoveryCapsule': _encodedData(genesis.recoveryCapsule),
    'lastOperationId': genesis.operationId,
    'updatedAt': '2026-07-26T05:00:00.000Z',
    'envelopes': <Object?>[
      <String, Object?>{
        'targetDeviceId': deviceId,
        'issuerDeviceId': deviceId,
        'envelopeVersion': 1,
        'keyEpoch': 1,
        'accountKeyEnvelope': _encodedData(
          accountKeyEnvelope ??
              _filledBytes(cloudSyncAccountKeyEnvelopeBytes, 9),
        ),
      },
    ],
  };
}

Map<String, Object?> _securityStateDataForTest({
  required int generation,
  required int keyEpoch,
  required String dataRekeyPhase,
  required Uint8List membershipManifest,
  required int recoveryCapsuleVersion,
  required Uint8List recoveryCapsule,
  required String operationId,
  String updatedAt = '2026-07-29T05:00:00.000Z',
}) {
  return <String, Object?>{
    'generation': generation,
    'keyEpoch': keyEpoch,
    'dataRekeyPhase': dataRekeyPhase,
    'membershipManifest': _encodedData(membershipManifest),
    'membershipManifestDigest': _encodedData(
      Uint8List.fromList(sha256.convert(membershipManifest).bytes),
    ),
    'recoveryPublicKeyVersion': 1,
    'recoveryPublicKey': _encodedBytes(cloudSyncRecoveryPublicKeyBytes, 71),
    'recoveryCapsuleVersion': recoveryCapsuleVersion,
    'recoveryCapsule': _encodedData(recoveryCapsule),
    'lastOperationId': operationId,
    'updatedAt': updatedAt,
    'envelopes': <Object?>[
      <String, Object?>{
        'targetDeviceId': _deviceId1,
        'issuerDeviceId': _issuerDeviceId,
        'envelopeVersion': 1,
        'keyEpoch': keyEpoch,
        'accountKeyEnvelope': _encodedBytes(
          cloudSyncAccountKeyEnvelopeBytes,
          72,
        ),
      },
    ],
  };
}

Map<String, Object?> _securityHistoryItemForTest({
  required int generation,
  required int keyEpoch,
  required int manifestSeed,
  required int recoveryCapsuleVersion,
  required String operationId,
}) {
  final manifest = _filledBytes(
    cloudSyncMembershipManifestMinimumBytes,
    manifestSeed,
  );
  return <String, Object?>{
    'generation': generation,
    'keyEpoch': keyEpoch,
    'membershipManifest': _encodedData(manifest),
    'membershipManifestDigest': _encodedData(
      Uint8List.fromList(sha256.convert(manifest).bytes),
    ),
    'recoveryPublicKeyVersion': 1,
    'recoveryPublicKey': _encodedBytes(cloudSyncRecoveryPublicKeyBytes, 71),
    'recoveryCapsuleVersion': recoveryCapsuleVersion,
    'recoveryCapsule': _encodedBytes(160 + generation, 73 + generation),
    'operationId': operationId,
    'committedAt':
        '2026-07-29T${generation.toString().padLeft(2, '0')}:00:00.000Z',
  };
}

Map<String, Object?> _securityCurrentProjectionForTest(
  Map<String, Object?> state,
) {
  return <String, Object?>{
    'generation': state['generation'],
    'keyEpoch': state['keyEpoch'],
    'dataRekeyPhase': state['dataRekeyPhase'],
    'membershipManifestDigest': state['membershipManifestDigest'],
    'recoveryPublicKeyVersion': state['recoveryPublicKeyVersion'],
    'recoveryPublicKey': state['recoveryPublicKey'],
    'recoveryCapsuleVersion': state['recoveryCapsuleVersion'],
    'updatedAt': state['updatedAt'],
  };
}

Map<String, Object?> _registrationAuthenticatedData({
  Map<String, Object?>? securityState,
  String deviceId = _deviceId1,
  String loginName = 'alice',
}) {
  return <String, Object?>{
    ..._authenticatedData(
      keyEpoch: 1,
      deviceId: deviceId,
      loginName: loginName,
    ),
    'securityState': securityState ?? _registrationSecurityStateData(),
  }..remove('keyEpoch');
}

Map<String, Object?> _pairingAuthenticatedData({
  required String token,
  int keyEpoch = 7,
  String deviceId = _deviceId1,
  String loginName = 'alice',
  String pairingId = _pairingId,
  String issuerDeviceId = _issuerDeviceId,
  Uint8List? membershipManifest,
  Uint8List? recoveryPublicKey,
  Uint8List? recoveryCapsule,
  Uint8List? accountKeyEnvelope,
}) {
  final manifest =
      membershipManifest ??
      _filledBytes(cloudSyncMembershipManifestMinimumBytes, 33);
  final manifestDigest = _encodedData(
    Uint8List.fromList(sha256.convert(manifest).bytes),
  );
  final state = <String, Object?>{
    'generation': 2,
    'keyEpoch': keyEpoch,
    'dataRekeyPhase': 'ready',
    'membershipManifest': _encodedData(manifest),
    'membershipManifestDigest': manifestDigest,
    'recoveryPublicKeyVersion': 1,
    'recoveryPublicKey': _encodedData(
      recoveryPublicKey ?? _filledBytes(cloudSyncRecoveryPublicKeyBytes, 34),
    ),
    'recoveryCapsuleVersion': 1,
    'recoveryCapsule': _encodedData(
      recoveryCapsule ?? _filledBytes(cloudSyncRecoveryCapsuleBytes, 35),
    ),
    'lastOperationId': pairingId,
    'updatedAt': '2026-07-26T05:01:00.000Z',
    'envelopes': <Object?>[
      <String, Object?>{
        'targetDeviceId': deviceId,
        'issuerDeviceId': issuerDeviceId,
        'envelopeVersion': 1,
        'keyEpoch': keyEpoch,
        'accountKeyEnvelope': _encodedData(
          accountKeyEnvelope ??
              _filledBytes(cloudSyncAccountKeyEnvelopeBytes, 21),
        ),
      },
    ],
  };
  final data = <String, Object?>{
    ..._authenticatedData(
      token: token,
      keyEpoch: keyEpoch,
      deviceId: deviceId,
      loginName: loginName,
    ),
    'pairingId': pairingId,
    'issuerDeviceId': issuerDeviceId,
    'keyEpoch': keyEpoch,
    'securityGeneration': 2,
    'membershipManifestDigest': manifestDigest,
    'securityState': state,
  };
  final device = <String, Object?>{...copyCloudSyncJsonMap(data['device'])};
  device['authGeneration'] = 1;
  device['sessionGeneration'] = 2;
  data['device'] = device;
  return data;
}

CloudSyncAccountSecurityState _copySecurityState(
  CloudSyncAccountSecurityState source, {
  Uint8List? membershipManifest,
  List<CloudSyncAccountSecurityEnvelope>? envelopes,
}) {
  final manifest = membershipManifest ?? source.membershipManifest;
  return CloudSyncAccountSecurityState(
    generation: source.generation,
    keyEpoch: source.keyEpoch,
    dataRekeyPhase: source.dataRekeyPhase,
    membershipManifest: manifest,
    membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
      Uint8List.fromList(sha256.convert(manifest).bytes),
    ),
    recoveryPublicKeyVersion: source.recoveryPublicKeyVersion,
    recoveryPublicKey: source.recoveryPublicKey,
    recoveryCapsuleVersion: source.recoveryCapsuleVersion,
    recoveryCapsule: source.recoveryCapsule,
    lastOperationId: source.lastOperationId,
    updatedAt: source.updatedAt,
    envelopes: envelopes ?? source.envelopes,
  );
}

CloudSyncAuthenticatedSession _copyAuthenticatedSession(
  CloudSyncAuthenticatedSession source, {
  int? authGeneration,
  CloudSyncAccountSecurityState? securityState,
  CloudSyncDevicePairingConsumptionReceipt? pairingReceipt,
}) {
  return CloudSyncAuthenticatedSession(
    token: source.token,
    tokenExpiresAt: source.tokenExpiresAt,
    keyEpoch: source.keyEpoch,
    authGeneration: authGeneration ?? source.authGeneration,
    sessionGeneration: source.sessionGeneration,
    user: source.user,
    device: source.device,
    deviceKeyVersion: source.deviceKeyVersion,
    securityState: securityState ?? source.securityState,
    pairingReceipt: pairingReceipt ?? source.pairingReceipt,
  );
}

String _requiredTestString(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value is! String) {
    throw StateError('$key 不是字符串');
  }
  return value;
}

Map<String, Object?> _pairingTargetJson() {
  return <String, Object?>{
    'id': _deviceId2,
    'name': 'Android 手机',
    'platform': 'android',
    'clientVersion': '1.2.3',
    'keyVersion': 1,
    'authGeneration': 0,
    'signingPublicKey': _encodedBytes(cloudSyncDevicePublicKeyBytes, 4),
    'keyAgreementPublicKey': _encodedBytes(cloudSyncDevicePublicKeyBytes, 5),
  };
}

CloudSyncDevicePairingCreated _pairingQrCreated({DateTime? expiresAt}) {
  return CloudSyncDevicePairingCreated(
    pairingId: _pairingId,
    accountContextId: _userId,
    challenge: _filledBytes(cloudSyncDeviceChallengeBytes, 18),
    expiresAt: expiresAt ?? DateTime.utc(2026, 7, 26, 5, 5),
    targetDevice: CloudSyncDevicePairingTarget(
      id: _deviceId2,
      name: 'Android 手机',
      platform: CloudSyncPlatform.android,
      clientVersion: '1.2.3',
      keyVersion: 1,
      authGeneration: 0,
      signingPublicKey: _filledBytes(cloudSyncDevicePublicKeyBytes, 4),
      keyAgreementPublicKey: _filledBytes(cloudSyncDevicePublicKeyBytes, 5),
    ),
  );
}

CloudSyncDevicePairingQrPayload _pairingQrPayload({
  required Uint8List pairingSecret,
  String normalizedServiceOrigin = defaultCloudSyncBaseUrl,
  DateTime? now,
  DateTime? expiresAt,
  int protocolVersion = cloudSyncOpaqueProtocolVersion,
  CloudSyncPlatform platform = CloudSyncPlatform.android,
  String deviceName = 'Android 手机',
  String clientVersion = '1.2.3',
  int keyVersion = 1,
  String pairingId = _pairingId,
  String accountContextId = _userId,
  String targetDeviceId = _deviceId2,
  Uint8List? challenge,
  Uint8List? signingPublicKey,
  Uint8List? keyAgreementPublicKey,
}) {
  return CloudSyncDevicePairingQrPayload.takeOwnership(
    normalizedServiceOrigin: normalizedServiceOrigin,
    protocolVersion: protocolVersion,
    platform: platform,
    untrustedDeviceName: deviceName,
    untrustedClientVersion: clientVersion,
    keyVersion: keyVersion,
    expiresAt: expiresAt ?? DateTime.utc(2026, 7, 26, 5, 5),
    pairingId: pairingId,
    accountContextId: accountContextId,
    targetDeviceId: targetDeviceId,
    challenge: challenge ?? _filledBytes(cloudSyncDeviceChallengeBytes, 18),
    signingPublicKey:
        signingPublicKey ?? _filledBytes(cloudSyncDevicePublicKeyBytes, 4),
    keyAgreementPublicKey:
        keyAgreementPublicKey ?? _filledBytes(cloudSyncDevicePublicKeyBytes, 5),
    pairingSecret: pairingSecret,
    now: now ?? DateTime.utc(2026, 7, 26, 5),
  );
}

Uint8List _validPairingQrFrame() {
  final payload = _pairingQrPayload(
    pairingSecret: _filledBytes(cloudSyncPairingSecretBytes, 24),
  );
  try {
    return CloudSyncDevicePairingQrCodec.encode(
      payload,
      now: DateTime.utc(2026, 7, 26, 5),
    );
  } finally {
    payload.dispose();
  }
}

void _refreshPairingQrCrc(Uint8List frame) {
  final crcOffset = frame.length - 4;
  ByteData.sublistView(frame).setUint32(
    crcOffset,
    getCrc32(Uint8List.sublistView(frame, 0, crcOffset)),
    Endian.big,
  );
}

Uint8List _replacePairingQrServiceOrigin(
  Uint8List validFrame,
  String serviceOrigin,
) {
  final originBytes = ascii.encode(serviceOrigin);
  if (originBytes.length > 0xff) {
    throw ArgumentError.value(serviceOrigin, 'serviceOrigin');
  }
  final previousOriginLength = validFrame[15];
  final frame = Uint8List(
    validFrame.length - previousOriginLength + originBytes.length,
  );
  frame.setRange(0, 208, validFrame);
  frame[15] = originBytes.length;
  ByteData.sublistView(frame).setUint16(6, frame.length, Endian.big);
  frame.setRange(208, 208 + originBytes.length, originBytes);
  frame.setRange(
    208 + originBytes.length,
    frame.length - 4,
    Uint8List.sublistView(
      validFrame,
      208 + previousOriginLength,
      validFrame.length - 4,
    ),
  );
  _refreshPairingQrCrc(frame);
  validFrame.fillRange(0, validFrame.length, 0);
  return frame;
}

Map<String, Object?> _trustedDeviceJson({String status = 'active'}) {
  return <String, Object?>{
    'id': _deviceId2,
    'name': 'Android 手机',
    'platform': 'android',
    'clientVersion': '1.2.3',
    'authGeneration': 1,
    'status': status,
    'createdAt': '2026-07-26T05:00:00.000Z',
    'lastSeenAt': '2026-07-26T06:00:00.000Z',
    'revokedAt': status == 'revoked' ? '2026-07-26T07:00:00.000Z' : null,
    'isCurrent': false,
  };
}

extension _DeviceStateBlobStoreTestSetup on DeviceStateBlobStore {
  Future<DeviceStateBlobSnapshot> write({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required Uint8List blob,
  }) async {
    final current = await readVersioned(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return compareAndSwap(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
      expectedVersion: current?.version,
      blob: blob,
    );
  }
}

void main() {
  SecureCoreTestStoreScope? testStoreScope;

  setUpAll(() {
    testStoreScope = SecureCoreTestStoreScope.open();
  });
  tearDownAll(() {
    testStoreScope?.close();
  });

  test('桌面端不能注册首个可信设备且不会创建本地设备状态', () async {
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    final store = DeviceStateBlobStore(installationRoot: root);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: 'http://127.0.0.1:1',
      accountClient: client,
      deviceStateStore: store,
      secureCore: const KelivoSecureCore(),
    );
    addTearDown(() async {
      client.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final password = Uint8List.fromList(utf8.encode('password'));
    await expectLater(
      authenticator.registerFirstDevice(
        loginName: 'desktop-user',
        displayName: 'Desktop User',
        password: password,
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(password, everyElement(0));
    expect(
      await store.read(
        normalizedBaseUrl: 'http://127.0.0.1:1',
        normalizedLoginName: 'desktop-user',
      ),
      isNull,
    );
  });

  test('业务校验与密码清理同时失败时保留主异常', () async {
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    client.setToken(_fullToken);
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: 'http://127.0.0.1:1',
      accountClient: client,
      deviceStateStore: DeviceStateBlobStore(installationRoot: root),
      secureCore: const KelivoSecureCore(),
    );
    addTearDown(() async {
      client.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final readOnlyPassword = Uint8List.fromList(
      utf8.encode('password'),
    ).asUnmodifiableView();
    await expectLater(
      authenticator.loginDevice(
        loginName: 'invalid login name',
        password: readOnlyPassword,
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      ),
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.validation,
        ),
      ),
    );
    await expectLater(
      client.listDevices(),
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.unauthenticated,
        ),
      ),
    );
  });

  test('登录网络失败后保留可认证重开的设备状态且不会伪成功', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    const baseUrl = 'http://127.0.0.1:1';
    const normalizedLoginName = 'network-user';
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final store = DeviceStateBlobStore(installationRoot: root);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: '$baseUrl/',
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<void> login() async {
      await authenticator.loginDevice(
        loginName: ' Network-User ',
        password: Uint8List.fromList(utf8.encode('password')),
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      );
    }

    await expectLater(login(), throwsA(isA<CloudSyncException>()));
    final firstBlob = await store.read(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    expect(firstBlob, hasLength(DeviceStateBlobStore.blobLength));

    await expectLater(login(), throwsA(isA<CloudSyncException>()));
    final secondBlob = await store.read(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    expect(secondBlob, orderedEquals(firstBlob!));
  });

  test('同一认证器并发登录时第二个操作失败关闭', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    final firstRequestArrived = Completer<void>();
    final releaseFirstRequest = Completer<void>();
    var requestCount = 0;
    final subscription = server.listen((request) async {
      requestCount++;
      if (requestCount == 1) {
        firstRequestArrived.complete();
        await releaseFirstRequest.future;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'protocolVersion': cloudSyncOpaqueProtocolVersion,
            'attemptId': _attemptId1,
            'accountBinding': _accountContextId,
            'deviceChallenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 1),
            'credentialResponse': _encodedBytes(
              cloudSyncOpaqueCredentialResponseBytes,
              2,
            ),
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
          },
        }),
      );
      await request.response.close();
    });
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<Object?> capture(Future<Object?> operation) async {
      try {
        await operation;
        return null;
      } catch (error) {
        return error;
      }
    }

    final firstPassword = Uint8List.fromList(utf8.encode('first-password'));
    final firstOutcome = capture(
      authenticator.loginDevice(
        loginName: 'first-user',
        password: firstPassword,
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      ),
    );
    await firstRequestArrived.future;

    final secondPassword = Uint8List.fromList(utf8.encode('second-password'));
    final secondOutcome = await capture(
      authenticator.loginDevice(
        loginName: 'second-user',
        password: secondPassword,
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      ),
    );
    releaseFirstRequest.complete();
    final completedFirstOutcome = await firstOutcome;

    expect(
      secondOutcome,
      isA<CloudSyncException>()
          .having((error) => error.kind, 'kind', CloudSyncFailureKind.conflict)
          .having(
            (error) => error.serverCode,
            'serverCode',
            'SYNC_AUTHENTICATION_IN_PROGRESS',
          ),
    );
    expect(
      completedFirstOutcome,
      isA<KelivoSecureCoreException>().having(
        (error) => error.status,
        'status',
        KelivoSecureCoreStatus.opaqueMessageInvalid,
      ),
    );
    expect(requestCount, 1);
    expect(firstPassword, everyElement(0));
    expect(secondPassword, everyElement(0));
    expect(
      await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: 'second-user',
      ),
      isNull,
    );
  });

  test('设备状态存在但持久密钥槽缺失时失败关闭', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    const baseUrl = 'https://missing-slot.example';
    final loginName = 'missing${DateTime.now().microsecondsSinceEpoch}';
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final store = DeviceStateBlobStore(installationRoot: root);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: Uint8List(DeviceStateBlobStore.blobLength),
    );

    await expectLater(
      authenticator.loginDevice(
        loginName: loginName,
        password: Uint8List.fromList(utf8.encode('password')),
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.slotNotFound,
        ),
      ),
    );
  });

  test('设备状态密文损坏时不会重建身份掩盖认证失败', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    const baseUrl = 'http://127.0.0.1:1';
    const loginName = 'damaged-user';
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final store = DeviceStateBlobStore(installationRoot: root);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });
    Future<void> login() async {
      await authenticator.loginDevice(
        loginName: loginName,
        password: Uint8List.fromList(utf8.encode('password')),
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      );
    }

    await expectLater(login(), throwsA(isA<CloudSyncException>()));
    final blob = await store.read(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
    );
    final damagedBlob = Uint8List.fromList(blob!)..last ^= 1;
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: damagedBlob,
    );

    await expectLater(
      login(),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.deviceStateAuthenticationFailed,
        ),
      ),
    );
  });

  test('OPAQUE 账户伪名不同于本地用户标识时仍继续密码学登录', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    const loginName = 'bound-user';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final slotId = _authenticatorSlotId(baseUrl, loginName);
    final key = await core.createSlot(slotId);
    final identity = await core.generateDeviceIdentity();
    final ark = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 7,
    );
    final stateBlob = await core.sealDeviceState(
      key,
      identity,
      deviceId: _rawUuid(_deviceId1),
      keyVersion: 1,
      ark: ark,
      account: KelivoDeviceStateAccountBinding(
        userId: _rawUuid(_userId),
        keyEpoch: 7,
      ),
    );
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: stateBlob,
    );
    await core.closeAccountRootKey(ark);
    await core.closeDeviceIdentity(identity);
    await core.close(key);
    expect(_accountContextId, isNot(_userId));

    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final loginFuture = authenticator.loginDevice(
      loginName: loginName,
      password: Uint8List.fromList(utf8.encode('password')),
      deviceName: 'Windows 主机',
      platform: CloudSyncPlatform.windows,
      clientVersion: '1.2.3',
    );
    final request = await requestFuture;
    final body = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(request).join()),
    );
    expect(body['deviceId'], _deviceId1);
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'attemptId': _attemptId1,
          'accountBinding': _accountContextId,
          'deviceChallenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 1),
          'credentialResponse': _encodedBytes(
            cloudSyncOpaqueCredentialResponseBytes,
            2,
          ),
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        },
      }),
    );
    await request.response.close();
    await expectLater(
      loginFuture,
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.opaqueMessageInvalid,
        ),
      ),
    );

    final reopenedKey = await core.openSlot(slotId);
    final reopened = await core.openDeviceState(
      reopenedKey,
      stateBlob: (await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ))!,
    );
    expect(reopened.binding.account?.keyEpoch, 7);
    expect(reopened.binding.account?.userId, orderedEquals(_rawUuid(_userId)));
    await core.closeAccountRootKey(reopened.ark!);
    await core.closeDeviceIdentity(reopened.identity);
    await core.close(reopenedKey);
  });

  test('移动注册的畸形 OPAQUE 响应保留可重开的未绑定设备状态', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    const loginName = 'mobile-user';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final requestFuture = server.first;
    final registrationFuture = authenticator.registerFirstDevice(
      loginName: loginName,
      displayName: 'Mobile User',
      password: Uint8List.fromList(utf8.encode('password')),
      deviceName: 'Android 手机',
      platform: CloudSyncPlatform.android,
      clientVersion: '1.2.3',
    );
    final request = await requestFuture;
    final body = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(request).join()),
    );
    expect(body['platform'], 'android');
    expect(body['deviceKeyVersion'], 1);
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'attemptId': _attemptId1,
          'userId': _userId,
          'accountBinding': _accountContextId,
          'deviceChallenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 1),
          'registrationResponse': _encodedBytes(
            cloudSyncOpaqueRegistrationResponseBytes,
          ),
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        },
      }),
    );
    await request.response.close();
    await expectLater(
      registrationFuture,
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.opaqueMessageInvalid,
        ),
      ),
    );

    final key = await core.openSlot(_authenticatorSlotId(baseUrl, loginName));
    final opened = await core.openDeviceState(
      key,
      stateBlob: (await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ))!,
    );
    expect(opened.binding.account, isNull);
    expect(opened.binding.keyVersion, 1);
    expect(body['deviceId'], _uuidStringForTest(opened.binding.deviceId));
    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );
    await core.closeDeviceIdentity(opened.identity);
    await core.close(key);
  });

  test('首设备注册响应丢失后新认证器原样重放且提交确认前保留事务', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    const loginName = 'recover-registration';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final seededRegistration = await _seedPendingRegistration(
      core: core,
      store: store,
      baseUrl: baseUrl,
      loginName: loginName,
      attemptExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
    final expectedRequest = seededRegistration.expectedRequest;
    final firstClient = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final firstAuthenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: firstClient,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      firstClient.close(force: true);
      await requests.cancel();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final firstPassword = Uint8List.fromList(utf8.encode('password'));
    final firstResult = firstAuthenticator.registerFirstDevice(
      loginName: loginName,
      displayName: 'Recovery User',
      password: firstPassword,
      deviceName: 'Android 手机',
      platform: CloudSyncPlatform.android,
      clientVersion: '1.2.3',
    );
    expect(await requests.moveNext(), isTrue);
    final firstRequest = requests.current;
    final firstBody = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(firstRequest).join()),
    );
    expect(firstRequest.uri.path, '/api/auth/opaque-registration/finish');
    expect(firstBody, expectedRequest);
    final firstSocket = await firstRequest.response.detachSocket();
    firstSocket.destroy();
    await expectLater(firstResult, throwsA(isA<CloudSyncException>()));
    expect(firstPassword, everyElement(0));
    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNotNull,
    );

    final persistedKey = await core.openSlot(
      _authenticatorSlotId(baseUrl, loginName),
    );
    final persistedState = await core.openDeviceState(
      persistedKey,
      stateBlob: (await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ))!,
    );
    expect(persistedState.binding.account?.keyEpoch, 1);
    expect(
      persistedState.binding.account?.userId,
      orderedEquals(_rawUuid(_userId)),
    );
    await core.closeAccountRootKey(persistedState.ark!);
    await core.closeDeviceIdentity(persistedState.identity);
    await core.close(persistedKey);

    firstClient.close(force: true);
    final secondClient = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final secondAuthenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: secondClient,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() => secondClient.close(force: true));
    final secondPassword = Uint8List.fromList(utf8.encode('password'));
    final secondResultFuture = secondAuthenticator.registerFirstDevice(
      loginName: loginName,
      displayName: 'Ignored On Recovery',
      password: secondPassword,
      deviceName: 'Android 手机',
      platform: CloudSyncPlatform.android,
      clientVersion: '1.2.3',
    );
    expect(await requests.moveNext(), isTrue);
    final secondRequest = requests.current;
    final secondBody = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(secondRequest).join()),
    );
    expect(secondRequest.uri.path, '/api/auth/opaque-registration/finish');
    expect(secondBody, expectedRequest);
    secondRequest.response.headers.contentType = ContentType.json;
    secondRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': _registrationAuthenticatedData(
          securityState: seededRegistration.securityState,
          loginName: loginName,
        ),
      }),
    );
    await secondRequest.response.close();

    final secondResult = await secondResultFuture;
    expect(secondResult.user.id, _userId);
    expect(secondResult.device.id, _deviceId1);
    expect(secondResult.deviceKeyVersion, 1);
    expect(secondPassword, everyElement(0));
    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNotNull,
    );
    await secondAuthenticator.confirmFirstDeviceRegistration(
      loginName: loginName,
      session: secondResult,
    );
    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );
  });

  for (final scenario
      in <
        ({String name, Duration attemptExpiryOffset, String expectedServerCode})
      >[
        (
          name: '未过期注册事务被拒绝时保留服务端错误且不回滚 ARK',
          attemptExpiryOffset: const Duration(minutes: 5),
          expectedServerCode: 'AUTH_REGISTRATION_FAILED',
        ),
        (
          name: '已过期注册恢复要求正常登录且不回滚 ARK',
          attemptExpiryOffset: const Duration(minutes: -1),
          expectedServerCode: 'SYNC_REGISTRATION_RECOVERY_LOGIN_REQUIRED',
        ),
      ]) {
    test(scenario.name, () async {
      const core = KelivoSecureCore();
      if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestFuture = server.first;
      final baseUrl = 'http://${server.address.address}:${server.port}';
      final loginName = scenario.attemptExpiryOffset.isNegative
          ? 'expired-registration'
          : 'rejected-registration';
      final testRoot = Directory(
        '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}e2ee_authenticator_tests',
      );
      await testRoot.create(recursive: true);
      final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
      final store = DeviceStateBlobStore(installationRoot: root);
      await _seedPendingRegistration(
        core: core,
        store: store,
        baseUrl: baseUrl,
        loginName: loginName,
        attemptExpiresAt: DateTime.now().toUtc().add(
          scenario.attemptExpiryOffset,
        ),
      );
      final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
      final authenticator = E2eeAccountAuthenticator(
        baseUrl: baseUrl,
        accountClient: client,
        deviceStateStore: store,
        secureCore: core,
      );
      addTearDown(() async {
        client.close(force: true);
        await server.close(force: true);
        if (await root.exists()) await root.delete(recursive: true);
      });

      final password = Uint8List.fromList(utf8.encode('password'));
      final result = authenticator.registerFirstDevice(
        loginName: loginName,
        displayName: 'Recovery User',
        password: password,
        deviceName: 'Android 手机',
        platform: CloudSyncPlatform.android,
        clientVersion: '1.2.3',
      );
      final request = await requestFuture;
      await utf8.decoder.bind(request).join();
      expect(request.uri.path, '/api/auth/opaque-registration/finish');
      request.response
        ..statusCode = 400
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'code': 'AUTH_REGISTRATION_FAILED',
              'message': 'registration failed',
              'retryable': false,
            },
            'requestId': 'registration-recovery-failure',
          }),
        );
      await request.response.close();

      await expectLater(
        result,
        throwsA(
          isA<CloudSyncException>().having(
            (error) => error.serverCode,
            'serverCode',
            scenario.expectedServerCode,
          ),
        ),
      );
      expect(password, everyElement(0));
      expect(
        await store.readPendingRegistrationEnvelope(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
        ),
        isNotNull,
      );
      final key = await core.openSlot(_authenticatorSlotId(baseUrl, loginName));
      final opened = await core.openDeviceState(
        key,
        stateBlob: (await store.read(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
        ))!,
      );
      expect(opened.binding.account?.keyEpoch, 1);
      expect(opened.ark, isNotNull);
      await core.closeAccountRootKey(opened.ark!);
      await core.closeDeviceIdentity(opened.identity);
      await core.close(key);
    });
  }

  test('生产客户端固定使用官方服务地址', () {
    final client = CloudSyncClient();
    addTearDown(() => client.close(force: true));

    expect(client.baseUrl, 'https://kelivo.bemylover.top');
    expect(client.baseUrl, defaultCloudSyncBaseUrl);
  });

  test('完整会话令牌与设备引导令牌不可混淆且不会被日志输出', () {
    final generated = CloudSyncFullSessionToken.generate();
    final anotherGenerated = CloudSyncFullSessionToken.generate();

    expect(_fullToken.value, _fullTokenValue);
    expect(_onboardingToken.value, _onboardingTokenValue);
    expect(_fullToken.toString(), isNot(contains(_fullTokenValue)));
    expect(_onboardingToken.toString(), isNot(contains(_onboardingTokenValue)));
    expect(
      () => CloudSyncFullSessionToken.parse(_onboardingTokenValue),
      throwsFormatException,
    );
    expect(
      () => CloudSyncOnboardingToken.parse(_fullTokenValue),
      throwsFormatException,
    );
    expect(
      () => CloudSyncFullSessionToken.parse('kelivo_short'),
      throwsFormatException,
    );
    expect(
      CloudSyncFullSessionToken.parse(generated.value).value,
      generated.value,
    );
    expect(anotherGenerated.value, isNot(generated.value));
  });

  test('配对成员清单提交严格绑定代次、清单字节与摘要', () {
    final currentDigestBytes = _filledBytes(
      cloudSyncMembershipManifestDigestBytes,
      9,
    );
    final manifest = Uint8List.fromList(utf8.encode('manifest-envelope'));
    final commit = CloudSyncDevicePairingMembershipCommit(
      expectedSecurityGeneration: 7,
      expectedMembershipManifestDigest:
          CloudSyncMembershipManifestDigest.fromBytes(currentDigestBytes),
      nextMembershipManifestVersion: 8,
      nextMembershipManifest: manifest,
    );
    manifest.fillRange(0, manifest.length, 0);

    expect(commit.expectedSecurityGeneration, 7);
    expect(commit.nextMembershipManifestVersion, 8);
    expect(commit.nextMembershipManifest, utf8.encode('manifest-envelope'));
    expect(
      commit.nextMembershipManifestDigest.bytes,
      sha256.convert(commit.nextMembershipManifest).bytes,
    );
    expect(
      CloudSyncMembershipManifestDigest.parse(
        commit.nextMembershipManifestDigest.encoded,
      ).bytes,
      commit.nextMembershipManifestDigest.bytes,
    );

    for (final invalidFactory in <Object? Function()>[
      () => CloudSyncDevicePairingMembershipCommit(
        expectedSecurityGeneration: 0,
        expectedMembershipManifestDigest:
            commit.expectedMembershipManifestDigest,
        nextMembershipManifestVersion: 8,
        nextMembershipManifest: commit.nextMembershipManifest,
      ),
      () => CloudSyncDevicePairingMembershipCommit(
        expectedSecurityGeneration: 7,
        expectedMembershipManifestDigest:
            commit.expectedMembershipManifestDigest,
        nextMembershipManifestVersion: 0,
        nextMembershipManifest: commit.nextMembershipManifest,
      ),
      () => CloudSyncDevicePairingMembershipCommit(
        expectedSecurityGeneration: 7,
        expectedMembershipManifestDigest:
            commit.expectedMembershipManifestDigest,
        nextMembershipManifestVersion: 8,
        nextMembershipManifest: Uint8List(0),
      ),
      () => CloudSyncMembershipManifestDigest.parse(
        '${commit.nextMembershipManifestDigest.encoded}=',
      ),
    ]) {
      expect(invalidFactory, throwsFormatException);
    }
  });

  test('账户安全状态接受服务端边界内的可变长恢复胶囊', () {
    final manifest = _filledBytes(cloudSyncMembershipManifestMinimumBytes, 31);
    final recoveryCapsule = _filledBytes(208, 32);
    final state = CloudSyncAccountSecurityState(
      generation: 2,
      keyEpoch: 2,
      dataRekeyPhase: CloudSyncDataRekeyPhase.ready,
      membershipManifest: manifest,
      membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
        Uint8List.fromList(sha256.convert(manifest).bytes),
      ),
      recoveryPublicKeyVersion: 1,
      recoveryPublicKey: _filledBytes(cloudSyncRecoveryPublicKeyBytes, 33),
      recoveryCapsuleVersion: 2,
      recoveryCapsule: recoveryCapsule,
      lastOperationId: _attemptId2,
      updatedAt: DateTime.utc(2026, 7, 29),
      envelopes: <CloudSyncAccountSecurityEnvelope>[
        CloudSyncAccountSecurityEnvelope(
          targetDeviceId: _deviceId1,
          issuerDeviceId: _issuerDeviceId,
          envelopeVersion: 1,
          keyEpoch: 2,
          accountKeyEnvelope: _filledBytes(
            cloudSyncAccountKeyEnvelopeBytes,
            34,
          ),
        ),
      ],
    );
    recoveryCapsule.fillRange(0, recoveryCapsule.length, 0);

    expect(state.recoveryCapsule, everyElement(32));
    expect(state.recoveryCapsule, hasLength(208));
    final completedHistory = CloudSyncAccountSecurityHistoryPage(
      items: const <CloudSyncAccountSecurityHistoryItem>[],
      afterGeneration: state.generation,
      nextAfterGeneration: state.generation,
      pageSize: 100,
      hasMore: false,
      currentState: CloudSyncAccountSecurityCurrentProjection(
        generation: state.generation,
        keyEpoch: state.keyEpoch,
        dataRekeyPhase: state.dataRekeyPhase,
        membershipManifestDigest: state.membershipManifestDigest,
        recoveryPublicKeyVersion: state.recoveryPublicKeyVersion,
        recoveryPublicKey: state.recoveryPublicKey,
        recoveryCapsuleVersion: state.recoveryCapsuleVersion,
        updatedAt: state.updatedAt,
      ),
    );
    expect(completedHistory.items, isEmpty);
    expect(completedHistory.hasMore, isFalse);
  });

  test('设备轮换请求冻结公开密文并拒绝信封串线', () {
    final currentManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      41,
    );
    final nextManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      42,
    );
    final nextRecoveryCapsule = _filledBytes(208, 43);
    final accountKeyEnvelope = _filledBytes(
      cloudSyncAccountKeyEnvelopeBytes,
      44,
    );
    final currentDigest = CloudSyncMembershipManifestDigest.fromBytes(
      Uint8List.fromList(sha256.convert(currentManifest).bytes),
    );
    final request = CloudSyncDeviceRotationRequest(
      expectedGeneration: 2,
      expectedKeyEpoch: 2,
      expectedMembershipManifestDigest: currentDigest,
      operationId: _mutationId3,
      revokeDeviceId: _deviceId2,
      nextMembershipManifest: nextManifest,
      nextRecoveryCapsuleVersion: 3,
      nextRecoveryCapsule: nextRecoveryCapsule,
      envelopes: <CloudSyncDeviceRotationEnvelope>[
        CloudSyncDeviceRotationEnvelope(
          targetDeviceId: _deviceId1,
          envelopeVersion: 1,
          keyEpoch: 3,
          accountKeyEnvelope: accountKeyEnvelope,
        ),
      ],
    );
    nextManifest.fillRange(0, nextManifest.length, 0);
    nextRecoveryCapsule.fillRange(0, nextRecoveryCapsule.length, 0);
    accountKeyEnvelope.fillRange(0, accountKeyEnvelope.length, 0);

    expect(request.nextMembershipManifest, everyElement(42));
    expect(request.nextRecoveryCapsule, everyElement(43));
    expect(request.envelopes.single.accountKeyEnvelope, everyElement(44));
    expect(
      request.nextMembershipManifestDigest.bytes,
      sha256.convert(request.nextMembershipManifest).bytes,
    );
    final maximumCapsuleRequest = CloudSyncDeviceRotationRequest(
      expectedGeneration: 2,
      expectedKeyEpoch: 2,
      expectedMembershipManifestDigest: currentDigest,
      operationId: _mutationId3,
      revokeDeviceId: _deviceId2,
      nextMembershipManifest: request.nextMembershipManifest,
      nextRecoveryCapsuleVersion: 3,
      nextRecoveryCapsule: _filledBytes(
        cloudSyncRecoveryCapsuleMaximumBytes,
        45,
      ),
      envelopes: request.envelopes,
    );
    expect(
      maximumCapsuleRequest.nextRecoveryCapsule,
      hasLength(cloudSyncRecoveryCapsuleMaximumBytes),
    );

    for (final invalidFactory in <Object? Function()>[
      () => CloudSyncDeviceRotationRequest(
        expectedGeneration: 2,
        expectedKeyEpoch: 2,
        expectedMembershipManifestDigest: request.nextMembershipManifestDigest,
        operationId: _mutationId3,
        revokeDeviceId: _deviceId2,
        nextMembershipManifest: request.nextMembershipManifest,
        nextRecoveryCapsuleVersion: 3,
        nextRecoveryCapsule: request.nextRecoveryCapsule,
        envelopes: request.envelopes,
      ),
      () => CloudSyncDeviceRotationRequest(
        expectedGeneration: 2,
        expectedKeyEpoch: 2,
        expectedMembershipManifestDigest: currentDigest,
        operationId: _mutationId3,
        revokeDeviceId: _deviceId2,
        nextMembershipManifest: request.nextMembershipManifest,
        nextRecoveryCapsuleVersion: 3,
        nextRecoveryCapsule: request.nextRecoveryCapsule,
        envelopes: <CloudSyncDeviceRotationEnvelope>[
          CloudSyncDeviceRotationEnvelope(
            targetDeviceId: _deviceId1,
            envelopeVersion: 1,
            keyEpoch: 2,
            accountKeyEnvelope: request.envelopes.single.accountKeyEnvelope,
          ),
        ],
      ),
      () => CloudSyncDeviceRotationRequest(
        expectedGeneration: 2,
        expectedKeyEpoch: 2,
        expectedMembershipManifestDigest: currentDigest,
        operationId: _mutationId3,
        revokeDeviceId: _deviceId2,
        nextMembershipManifest: request.nextMembershipManifest,
        nextRecoveryCapsuleVersion: 3,
        nextRecoveryCapsule: request.nextRecoveryCapsule,
        envelopes: <CloudSyncDeviceRotationEnvelope>[
          CloudSyncDeviceRotationEnvelope(
            targetDeviceId: _issuerDeviceId,
            envelopeVersion: 1,
            keyEpoch: 3,
            accountKeyEnvelope: request.envelopes.single.accountKeyEnvelope,
          ),
          request.envelopes.single,
        ],
      ),
      () => CloudSyncDeviceRotationRequest(
        expectedGeneration: 2,
        expectedKeyEpoch: 2,
        expectedMembershipManifestDigest: currentDigest,
        operationId: _mutationId3,
        revokeDeviceId: _deviceId2,
        nextMembershipManifest: request.nextMembershipManifest,
        nextRecoveryCapsuleVersion: 3,
        nextRecoveryCapsule: request.nextRecoveryCapsule,
        envelopes: <CloudSyncDeviceRotationEnvelope>[
          CloudSyncDeviceRotationEnvelope(
            targetDeviceId: _deviceId2,
            envelopeVersion: 1,
            keyEpoch: 3,
            accountKeyEnvelope: request.envelopes.single.accountKeyEnvelope,
          ),
        ],
      ),
      () => CloudSyncDeviceRotationRequest(
        expectedGeneration: 2,
        expectedKeyEpoch: 0xffffffff,
        expectedMembershipManifestDigest: currentDigest,
        operationId: _mutationId3,
        revokeDeviceId: _deviceId2,
        nextMembershipManifest: request.nextMembershipManifest,
        nextRecoveryCapsuleVersion: 3,
        nextRecoveryCapsule: request.nextRecoveryCapsule,
        envelopes: const <CloudSyncDeviceRotationEnvelope>[],
      ),
      () => CloudSyncDeviceRotationRequest(
        expectedGeneration: 2,
        expectedKeyEpoch: 2,
        expectedMembershipManifestDigest: currentDigest,
        operationId: _mutationId3,
        revokeDeviceId: _deviceId2,
        nextMembershipManifest: request.nextMembershipManifest,
        nextRecoveryCapsuleVersion: 3,
        nextRecoveryCapsule: Uint8List(0),
        envelopes: request.envelopes,
      ),
      () => CloudSyncDeviceRotationRequest(
        expectedGeneration: 2,
        expectedKeyEpoch: 2,
        expectedMembershipManifestDigest: currentDigest,
        operationId: _mutationId3,
        revokeDeviceId: _deviceId2,
        nextMembershipManifest: request.nextMembershipManifest,
        nextRecoveryCapsuleVersion: 3,
        nextRecoveryCapsule: Uint8List(
          cloudSyncRecoveryCapsuleMaximumBytes + 1,
        ),
        envelopes: request.envelopes,
      ),
    ]) {
      expect(invalidFactory, throwsFormatException);
    }
  });

  test('安全状态历史与设备轮换使用稳定端点并保持恢复密文不透明', () async {
    final currentManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      81,
    );
    final currentStateData = _securityStateDataForTest(
      generation: 3,
      keyEpoch: 2,
      dataRekeyPhase: 'ready',
      membershipManifest: currentManifest,
      recoveryCapsuleVersion: 2,
      recoveryCapsule: _filledBytes(208, 82),
      operationId: _attemptId2,
    );
    final nextManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      83,
    );
    final rotation = CloudSyncDeviceRotationRequest(
      expectedGeneration: 3,
      expectedKeyEpoch: 2,
      expectedMembershipManifestDigest: CloudSyncMembershipManifestDigest.parse(
        _requiredTestString(currentStateData, 'membershipManifestDigest'),
      ),
      operationId: _mutationId3,
      revokeDeviceId: _deviceId2,
      nextMembershipManifest: nextManifest,
      nextRecoveryCapsuleVersion: 3,
      nextRecoveryCapsule: _filledBytes(212, 84),
      envelopes: <CloudSyncDeviceRotationEnvelope>[
        CloudSyncDeviceRotationEnvelope(
          targetDeviceId: _deviceId1,
          envelopeVersion: 1,
          keyEpoch: 3,
          accountKeyEnvelope: _filledBytes(
            cloudSyncAccountKeyEnvelopeBytes,
            85,
          ),
        ),
      ],
    );
    final requests = <(String, String, String?, CloudSyncJsonMap)>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      final rawBody = await utf8.decoder.bind(request).join();
      final body = rawBody.isEmpty
          ? <String, Object?>{}
          : copyCloudSyncJsonMap(jsonDecode(rawBody));
      requests.add((
        request.method,
        request.uri.path,
        request.headers.value(HttpHeaders.authorizationHeader),
        body,
      ));
      final Object data = switch (request.uri.path) {
        '/api/device/security-state/get' => currentStateData,
        '/api/device/security-state/history/list' => <String, Object?>{
          'items': <Object?>[
            _securityHistoryItemForTest(
              generation: 1,
              keyEpoch: 1,
              manifestSeed: 77,
              recoveryCapsuleVersion: 1,
              operationId: _attemptId1,
            ),
            _securityHistoryItemForTest(
              generation: 2,
              keyEpoch: 1,
              manifestSeed: 78,
              recoveryCapsuleVersion: 1,
              operationId: _pairingId,
            ),
          ],
          'afterGeneration': 0,
          'nextAfterGeneration': 2,
          'pageSize': 2,
          'hasMore': true,
          'currentState': _securityCurrentProjectionForTest(currentStateData),
        },
        '/api/device/rotation/commit' => <String, Object?>{
          'result': 'committed',
          'operationId': rotation.operationId,
          'revokedDeviceId': rotation.revokeDeviceId,
          'fromGeneration': rotation.expectedGeneration,
          'generation': rotation.expectedGeneration + 1,
          'keyEpoch': rotation.expectedKeyEpoch + 1,
          'dataRekeyPhase': 'rekey-pending',
          'membershipManifestDigest':
              rotation.nextMembershipManifestDigest.encoded,
          'committedAt': '2026-07-29T05:01:00.000Z',
        },
        _ => throw StateError('未预期的请求路径：${request.uri.path}'),
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'data': data}));
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final currentState = await client.getSecurityState();
    final history = await client.listSecurityStateHistory(pageSize: 2);
    final result = await client.commitDeviceRotation(rotation);

    expect(currentState.generation, 3);
    expect(currentState.recoveryCapsule, hasLength(208));
    expect(history.items.map((item) => item.generation), <int>[1, 2]);
    expect(history.nextAfterGeneration, 2);
    expect(history.hasMore, isTrue);
    expect(history.currentState.generation, 3);
    expect(result.generation, 4);
    expect(result.keyEpoch, 3);
    expect(result.dataRekeyPhase, CloudSyncDataRekeyPhase.rekeyPending);

    expect(
      requests.map((request) => (request.$1, request.$2)).toList(),
      <(String, String)>[
        ('GET', '/api/device/security-state/get'),
        ('POST', '/api/device/security-state/history/list'),
        ('POST', '/api/device/rotation/commit'),
      ],
    );
    expect(
      requests.map((request) => request.$3),
      everyElement('Bearer $_fullTokenValue'),
    );
    expect(requests[0].$4, isEmpty);
    expect(requests[1].$4, <String, Object?>{
      'afterGeneration': 0,
      'pageSize': 2,
    });
    expect(requests[2].$4, <String, Object?>{
      'expectedGeneration': 3,
      'expectedKeyEpoch': 2,
      'expectedMembershipManifestDigest':
          rotation.expectedMembershipManifestDigest.encoded,
      'operationId': rotation.operationId,
      'revokeDeviceId': rotation.revokeDeviceId,
      'nextMembershipManifest': _encodedData(rotation.nextMembershipManifest),
      'nextMembershipManifestDigest':
          rotation.nextMembershipManifestDigest.encoded,
      'nextRecoveryCapsuleVersion': rotation.nextRecoveryCapsuleVersion,
      'nextRecoveryCapsule': _encodedData(rotation.nextRecoveryCapsule),
      'envelopes': <Object?>[
        <String, Object?>{
          'targetDeviceId': _deviceId1,
          'envelopeVersion': 1,
          'keyEpoch': 3,
          'accountKeyEnvelope': _encodedData(
            rotation.envelopes.single.accountKeyEnvelope,
          ),
        },
      ],
    });
  });

  test('账户恢复 challenge、冻结历史与授权使用稳定协议字段', () async {
    final manifest = _filledBytes(cloudSyncMembershipManifestMinimumBytes, 91);
    final capsule = _filledBytes(161, 92);
    final requestDigest = _filledBytes(32, 93);
    final challengeFrame = _filledBytes(
      e2eeAccountRecoveryChallengeFrameBytes,
      94,
    );
    final sealedNonce = _filledBytes(e2eeAccountRecoverySealedNonceBytes, 95);
    final recoveryToken = CloudSyncAccountRecoveryToken.parse(
      'kelivo_recovery_${_encodedBytes(32, 96)}',
    );
    final nonceProof = _filledBytes(e2eeAccountRecoveryNonceProofBytes, 97);
    final trustSignature = _filledBytes(
      e2eeAccountRecoveryTrustSignatureBytes,
      98,
    );
    final historyItem = <String, Object?>{
      'generation': 1,
      'keyEpoch': 1,
      'membershipManifest': _encodedData(manifest),
      'membershipManifestDigest': _encodedData(
        Uint8List.fromList(sha256.convert(manifest).bytes),
      ),
      'recoveryPublicKeyVersion': 1,
      'recoveryPublicKey': _encodedBytes(cloudSyncRecoveryPublicKeyBytes, 99),
      'recoveryCapsuleVersion': 1,
      'recoveryCapsule': _encodedData(capsule),
      'operationId': _mutationId1,
      'committedAt': '2026-08-01T01:00:00.000Z',
    };
    final requests = <(String, String, String?, CloudSyncJsonMap)>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      final rawBody = await utf8.decoder.bind(request).join();
      final body = rawBody.isEmpty
          ? <String, Object?>{}
          : copyCloudSyncJsonMap(jsonDecode(rawBody));
      requests.add((
        request.method,
        request.uri.path,
        request.headers.value(HttpHeaders.authorizationHeader),
        body,
      ));
      final Object data = switch ((request.uri.path, body['action'])) {
        ('/api/auth/account-recovery/attempt/start', 'challenge') =>
          <String, Object?>{
            'action': 'challenge',
            'result': 'created',
            'protocolVersion': e2eeAccountRecoveryProtocolVersion,
            'attemptId': _attemptId1,
            'requestDigest': _encodedData(requestDigest),
            'challengeFrame': _encodedData(challengeFrame),
            'sealedNonce': _encodedData(sealedNonce),
            'securityGeneration': 1,
            'keyEpoch': 1,
            'membershipManifestDigest': historyItem['membershipManifestDigest'],
            'recoveryPublicKeyVersion': 1,
            'recoveryPublicKey': historyItem['recoveryPublicKey'],
            'recoveryCapsuleVersion': 1,
            'recoveryCapsule': _encodedData(capsule),
            'recoveryCapsuleDigest': _encodedData(
              Uint8List.fromList(sha256.convert(capsule).bytes),
            ),
            'dataState': <String, Object?>{
              'phase': 'ready',
              'dataGeneration': 1,
              'dataKeyEpoch': 1,
              'operationId': null,
              'targetKeyEpoch': null,
            },
            'expiresAt': '2026-08-01T02:00:00.000Z',
          },
        ('/api/auth/account-recovery/state/get', null) => <String, Object?>{
          'protocolVersion': e2eeAccountRecoveryProtocolVersion,
          'attemptId': _attemptId1,
          'status': 'authorized',
          'nextAction': 'recover-replace',
          'authorizedAt': '2026-08-01T01:30:00.000Z',
          'recoveryTokenExpiresAt': '2026-08-01T03:00:00.000Z',
          'securityState': <String, Object?>{
            'generation': 1,
            'keyEpoch': 1,
            'dataRekeyPhase': 'ready',
            'membershipManifest': _encodedData(manifest),
            'membershipManifestDigest': historyItem['membershipManifestDigest'],
            'recoveryPublicKeyVersion': 1,
            'recoveryPublicKey': historyItem['recoveryPublicKey'],
            'recoveryCapsuleVersion': 1,
            'recoveryCapsule': _encodedData(capsule),
            'lastOperationId': _mutationId1,
            'updatedAt': '2026-08-01T01:00:00.000Z',
            'envelopes': <Object?>[
              <String, Object?>{
                'targetDeviceId': _deviceId1,
                'issuerDeviceId': _issuerDeviceId,
                'envelopeVersion': 1,
                'keyEpoch': 1,
                'accountKeyEnvelope': _encodedBytes(
                  cloudSyncAccountKeyEnvelopeBytes,
                  100,
                ),
              },
            ],
          },
          'dataState': <String, Object?>{
            'phase': 'ready',
            'dataGeneration': 1,
            'dataKeyEpoch': 1,
            'operationId': null,
            'targetKeyEpoch': null,
          },
        },
        ('/api/auth/account-recovery/history/list', null) => <String, Object?>{
          'items': <Object?>[historyItem],
          'afterGeneration': 0,
          'nextAfterGeneration': 1,
          'pageSize': 100,
          'hasMore': false,
          'currentState': <String, Object?>{
            'generation': 1,
            'keyEpoch': 1,
            'dataRekeyPhase': 'ready',
            'membershipManifestDigest': historyItem['membershipManifestDigest'],
            'recoveryPublicKeyVersion': 1,
            'recoveryPublicKey': historyItem['recoveryPublicKey'],
            'recoveryCapsuleVersion': 1,
            'updatedAt': '2026-08-01T01:00:00.000Z',
          },
        },
        ('/api/auth/account-recovery/attempt/start', 'authorize') =>
          <String, Object?>{
            'action': 'authorized',
            'result': 'authorized',
            'protocolVersion': e2eeAccountRecoveryProtocolVersion,
            'attemptId': _attemptId1,
            'status': 'authorized',
            'nextAction': 'recover-replace',
            'recoveryTokenExpiresAt': '2026-08-01T03:00:00.000Z',
          },
        _ => throw StateError('未预期的账户恢复请求'),
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'data': data}));
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final authorization = E2eeAccountRecoveryBearer.onboarding(
      _onboardingToken,
    );

    final challenge = await client.createChallenge(
      onboardingToken: _onboardingToken,
      attemptId: _attemptId1,
    );
    final remoteState = await client.getAuthorizedState(
      recoveryToken: recoveryToken,
    );
    final history = await client.listFrozenHistory(
      authorization: authorization,
      attemptId: _attemptId1,
      challengeRequestDigest: requestDigest,
      afterGeneration: 0,
      pageSize: 100,
    );
    final receipt = await client.authorize(
      authorization: authorization,
      attemptId: _attemptId1,
      challengeRequestDigest: requestDigest,
      recoveryToken: recoveryToken,
      nonceProof: nonceProof,
      trustSignature: trustSignature,
    );

    expect(challenge.recoveryCapsule, capsule);
    expect(remoteState.securityState.recoveryCapsule, capsule);
    expect(history.items.single.recoveryCapsule, capsule);
    expect(receipt.nextAction, E2eeAccountRecoveryNextAction.recoverReplace);
    expect(
      requests.map((request) => (request.$1, request.$2)),
      <(String, String)>[
        ('POST', '/api/auth/account-recovery/attempt/start'),
        ('GET', '/api/auth/account-recovery/state/get'),
        ('POST', '/api/auth/account-recovery/history/list'),
        ('POST', '/api/auth/account-recovery/attempt/start'),
      ],
    );
    expect(requests.map((request) => request.$3), <String?>[
      'Bearer $_onboardingTokenValue',
      'Bearer ${recoveryToken.value}',
      'Bearer $_onboardingTokenValue',
      'Bearer $_onboardingTokenValue',
    ]);
    expect(requests[0].$4, <String, Object?>{
      'action': 'challenge',
      'protocolVersion': e2eeAccountRecoveryProtocolVersion,
      'attemptId': _attemptId1,
    });
    expect(requests[1].$4, isEmpty);
    expect(requests[2].$4, <String, Object?>{
      'afterGeneration': 0,
      'pageSize': 100,
      'attemptId': _attemptId1,
      'challengeRequestDigest': _encodedData(requestDigest),
    });
    expect(requests[3].$4, <String, Object?>{
      'action': 'authorize',
      'protocolVersion': e2eeAccountRecoveryProtocolVersion,
      'attemptId': _attemptId1,
      'challengeRequestDigest': _encodedData(requestDigest),
      'recoveryToken': recoveryToken.value,
      'nonceProof': _encodedData(nonceProof),
      'trustSignature': _encodedData(trustSignature),
    });
  });

  test('恢复 token 尚未生效时 state/get 转换为可识别状态', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });
    final recoveryToken = CloudSyncAccountRecoveryToken.generate();

    final stateFuture = client.getAuthorizedState(recoveryToken: recoveryToken);
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer ${recoveryToken.value}',
    );
    await _writeJsonResponse(request, <String, Object?>{
      'error': <String, Object?>{
        'code': 'AUTH_ACCOUNT_RECOVERY_TOKEN_INVALID',
        'message': 'not authorized yet',
        'retryable': false,
      },
      'requestId': 'account-recovery-state-1',
    }, statusCode: HttpStatus.unauthorized);

    await expectLater(
      stateFuture,
      throwsA(isA<E2eeAccountRecoveryTokenUnavailable>()),
    );
  });

  test('账户恢复 state/get 保留成员提交后的数据换钥动作', () async {
    final manifest = _filledBytes(cloudSyncMembershipManifestMinimumBytes, 114);
    final capsule = _filledBytes(cloudSyncRecoveryCapsuleBytes, 115);
    final responses = <Map<String, Object?>>[
      <String, Object?>{
        'protocolVersion': e2eeAccountRecoveryProtocolVersion,
        'attemptId': _attemptId1,
        'status': 'resume-committed',
        'nextAction': 'finish-first-data-rekey',
        'authorizedAt': '2026-08-01T01:00:00.000Z',
        'recoveryTokenExpiresAt': '2026-08-01T03:00:00.000Z',
        'securityState': _securityStateDataForTest(
          generation: 5,
          keyEpoch: 5,
          dataRekeyPhase: 'rekey-pending',
          membershipManifest: manifest,
          recoveryCapsuleVersion: 1,
          recoveryCapsule: capsule,
          operationId: _mutationId4,
        ),
        'dataState': <String, Object?>{
          'phase': 'rekey-pending',
          'dataGeneration': 7,
          'dataKeyEpoch': 4,
          'operationId': _mutationId5,
          'targetKeyEpoch': 5,
        },
      },
      <String, Object?>{
        'protocolVersion': e2eeAccountRecoveryProtocolVersion,
        'attemptId': _attemptId1,
        'status': 'replacement-committed',
        'nextAction': 'finish-second-data-rekey',
        'authorizedAt': '2026-08-01T01:00:00.000Z',
        'recoveryTokenExpiresAt': '2026-08-01T03:00:00.000Z',
        'securityState': _securityStateDataForTest(
          generation: 6,
          keyEpoch: 6,
          dataRekeyPhase: 'rekey-pending',
          membershipManifest: manifest,
          recoveryCapsuleVersion: 2,
          recoveryCapsule: capsule,
          operationId: _mutationId6,
        ),
        'dataState': <String, Object?>{
          'phase': 'rekey-pending',
          'dataGeneration': 8,
          'dataKeyEpoch': 5,
          'operationId': _mutationId6,
          'targetKeyEpoch': 6,
        },
      },
    ];
    var responseIndex = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/auth/account-recovery/state/get');
      await _writeJsonResponse(request, <String, Object?>{
        'data': responses[responseIndex++],
      });
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final recoveryToken = CloudSyncAccountRecoveryToken.generate();

    final resume = await client.getAuthorizedState(
      recoveryToken: recoveryToken,
    );
    final replacement = await client.getAuthorizedState(
      recoveryToken: recoveryToken,
    );

    expect(resume.status, E2eeAccountRecoveryRemoteStatus.resumeCommitted);
    expect(
      resume.nextAction,
      E2eeAccountRecoveryNextAction.finishFirstDataRekey,
    );
    expect(
      replacement.status,
      E2eeAccountRecoveryRemoteStatus.replacementCommitted,
    );
    expect(
      replacement.nextAction,
      E2eeAccountRecoveryNextAction.finishSecondDataRekey,
    );
  });

  test('账户恢复 resume 与 replacement 提交使用稳定协议并严格绑定回执', () async {
    final expectedManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      101,
    );
    final resumeManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      102,
    );
    final replacementManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      103,
    );
    final resumeEnvelope = _filledBytes(cloudSyncAccountKeyEnvelopeBytes, 104);
    final replacementEnvelope = _filledBytes(
      cloudSyncAccountKeyEnvelopeBytes,
      105,
    );
    final replacementCapsule = _filledBytes(cloudSyncRecoveryCapsuleBytes, 106);
    final recoveryToken = CloudSyncAccountRecoveryToken.parse(
      'kelivo_recovery_${_encodedBytes(32, 107)}',
    );
    final resume = E2eeAccountRecoveryResumeCommit(
      attemptId: _attemptId1,
      membership: E2eeAccountRecoveryMembershipCommit(
        expectedGeneration: 4,
        expectedKeyEpoch: 5,
        expectedMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              Uint8List.fromList(sha256.convert(expectedManifest).bytes),
            ),
        operationId: _mutationId4,
        nextMembershipManifest: resumeManifest,
        nextMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              Uint8List.fromList(sha256.convert(resumeManifest).bytes),
            ),
        envelope: E2eeAccountRecoveryEnvelope(
          envelopeVersion: 1,
          keyEpoch: 5,
          accountKeyEnvelope: resumeEnvelope,
        ),
      ),
      rekeyOperationId: _mutationId5,
    );
    final replacement = E2eeAccountRecoveryReplacementCommit(
      attemptId: _attemptId2,
      membership: E2eeAccountRecoveryMembershipCommit(
        expectedGeneration: 7,
        expectedKeyEpoch: 8,
        expectedMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              Uint8List.fromList(sha256.convert(expectedManifest).bytes),
            ),
        operationId: _mutationId6,
        nextMembershipManifest: replacementManifest,
        nextMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              Uint8List.fromList(sha256.convert(replacementManifest).bytes),
            ),
        envelope: E2eeAccountRecoveryEnvelope(
          envelopeVersion: 1,
          keyEpoch: 9,
          accountKeyEnvelope: replacementEnvelope,
        ),
      ),
      nextRecoveryCapsuleVersion: 3,
      nextRecoveryCapsule: replacementCapsule,
      completionSessionId: _deviceId5,
      completionSessionToken: _otherFullToken,
    );
    final requests = <(String, String, String?, CloudSyncJsonMap)>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      final body = copyCloudSyncJsonMap(
        jsonDecode(await utf8.decoder.bind(request).join()),
      );
      requests.add((
        request.method,
        request.uri.path,
        request.headers.value(HttpHeaders.authorizationHeader),
        body,
      ));
      final data = switch (request.uri.path) {
        '/api/auth/account-recovery/resume/commit' => <String, Object?>{
          'result': 'committed',
          'attemptId': _attemptId1,
          'status': 'resume-committed',
          'membershipOperationId': _mutationId4,
          'rekeyOperationId': _mutationId5,
          'generation': 5,
          'keyEpoch': 5,
          'nextAction': 'finish-first-data-rekey',
        },
        '/api/auth/account-recovery/replacement/commit' => <String, Object?>{
          'result': 'replayed',
          'attemptId': _attemptId2,
          'status': 'replacement-committed',
          'membershipOperationId': _mutationId6,
          'rekeyOperationId': _mutationId6,
          'generation': 8,
          'keyEpoch': 9,
          'nextAction': 'finish-second-data-rekey',
        },
        _ => throw StateError('未预期的账户恢复提交请求'),
      };
      await _writeJsonResponse(request, <String, Object?>{'data': data});
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final resumeReceipt = await client.commitRecoveryResume(
      recoveryToken: recoveryToken,
      request: resume,
    );
    final replacementReceipt = await client.commitRecoveryReplacement(
      recoveryToken: recoveryToken,
      request: replacement,
    );

    expect(resumeReceipt.result, E2eeAccountRecoveryCommitResult.committed);
    expect(resumeReceipt.kind, E2eeAccountRecoveryCommitKind.resume);
    expect(
      resumeReceipt.nextAction,
      E2eeAccountRecoveryNextAction.finishFirstDataRekey,
    );
    expect(replacementReceipt.result, E2eeAccountRecoveryCommitResult.replayed);
    expect(replacementReceipt.kind, E2eeAccountRecoveryCommitKind.replacement);
    expect(
      replacementReceipt.nextAction,
      E2eeAccountRecoveryNextAction.finishSecondDataRekey,
    );
    expect(
      requests.map((request) => (request.$1, request.$2)),
      <(String, String)>[
        ('POST', '/api/auth/account-recovery/resume/commit'),
        ('POST', '/api/auth/account-recovery/replacement/commit'),
      ],
    );
    expect(requests.map((request) => request.$3), <String?>[
      'Bearer ${recoveryToken.value}',
      'Bearer ${recoveryToken.value}',
    ]);
    expect(requests[0].$4, <String, Object?>{
      'protocolVersion': e2eeAccountRecoveryProtocolVersion,
      'expectedGeneration': 4,
      'expectedKeyEpoch': 5,
      'expectedMembershipManifestDigest': _encodedData(
        Uint8List.fromList(sha256.convert(expectedManifest).bytes),
      ),
      'operationId': _mutationId4,
      'nextMembershipManifest': _encodedData(resumeManifest),
      'nextMembershipManifestDigest': _encodedData(
        Uint8List.fromList(sha256.convert(resumeManifest).bytes),
      ),
      'envelope': <String, Object?>{
        'envelopeVersion': 1,
        'keyEpoch': 5,
        'accountKeyEnvelope': _encodedData(resumeEnvelope),
      },
      'rekeyOperationId': _mutationId5,
    });
    expect(requests[1].$4, <String, Object?>{
      'protocolVersion': e2eeAccountRecoveryProtocolVersion,
      'expectedGeneration': 7,
      'expectedKeyEpoch': 8,
      'expectedMembershipManifestDigest': _encodedData(
        Uint8List.fromList(sha256.convert(expectedManifest).bytes),
      ),
      'operationId': _mutationId6,
      'nextMembershipManifest': _encodedData(replacementManifest),
      'nextMembershipManifestDigest': _encodedData(
        Uint8List.fromList(sha256.convert(replacementManifest).bytes),
      ),
      'envelope': <String, Object?>{
        'envelopeVersion': 1,
        'keyEpoch': 9,
        'accountKeyEnvelope': _encodedData(replacementEnvelope),
      },
      'nextRecoveryCapsuleVersion': 3,
      'nextRecoveryCapsule': _encodedData(replacementCapsule),
      'completionSessionId': _deviceId5,
      'completionSessionToken': _otherFullTokenValue,
    });
  });

  test('账户恢复提交拒绝错误清单摘要与错配重放回执', () async {
    final expectedManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      108,
    );
    final nextManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      109,
    );
    final expectedDigest = CloudSyncMembershipManifestDigest.fromBytes(
      Uint8List.fromList(sha256.convert(expectedManifest).bytes),
    );
    final nextDigest = CloudSyncMembershipManifestDigest.fromBytes(
      Uint8List.fromList(sha256.convert(nextManifest).bytes),
    );
    final envelope = E2eeAccountRecoveryEnvelope(
      envelopeVersion: 1,
      keyEpoch: 5,
      accountKeyEnvelope: _filledBytes(cloudSyncAccountKeyEnvelopeBytes, 110),
    );
    expect(
      () => E2eeAccountRecoveryMembershipCommit(
        expectedGeneration: 4,
        expectedKeyEpoch: 5,
        expectedMembershipManifestDigest: expectedDigest,
        operationId: _mutationId4,
        nextMembershipManifest: nextManifest,
        nextMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              _filledBytes(cloudSyncMembershipManifestDigestBytes, 111),
            ),
        envelope: envelope,
      ),
      throwsA(isA<FormatException>()),
    );
    final wrongResumeEpochMembership = E2eeAccountRecoveryMembershipCommit(
      expectedGeneration: 4,
      expectedKeyEpoch: 5,
      expectedMembershipManifestDigest: expectedDigest,
      operationId: _mutationId4,
      nextMembershipManifest: nextManifest,
      nextMembershipManifestDigest: nextDigest,
      envelope: E2eeAccountRecoveryEnvelope(
        envelopeVersion: 1,
        keyEpoch: 6,
        accountKeyEnvelope: _filledBytes(cloudSyncAccountKeyEnvelopeBytes, 112),
      ),
    );
    expect(
      () => E2eeAccountRecoveryResumeCommit(
        attemptId: _attemptId1,
        membership: wrongResumeEpochMembership,
        rekeyOperationId: _mutationId5,
      ),
      throwsA(isA<FormatException>()),
    );
    final wrongReplacementEpochMembership = E2eeAccountRecoveryMembershipCommit(
      expectedGeneration: 4,
      expectedKeyEpoch: 5,
      expectedMembershipManifestDigest: expectedDigest,
      operationId: _mutationId4,
      nextMembershipManifest: nextManifest,
      nextMembershipManifestDigest: nextDigest,
      envelope: envelope,
    );
    expect(
      () => E2eeAccountRecoveryReplacementCommit(
        attemptId: _attemptId1,
        membership: wrongReplacementEpochMembership,
        nextRecoveryCapsuleVersion: 2,
        nextRecoveryCapsule: _filledBytes(cloudSyncRecoveryCapsuleBytes, 113),
        completionSessionId: _deviceId5,
        completionSessionToken: _otherFullToken,
      ),
      throwsA(isA<FormatException>()),
    );
    final request = E2eeAccountRecoveryResumeCommit(
      attemptId: _attemptId1,
      membership: E2eeAccountRecoveryMembershipCommit(
        expectedGeneration: 4,
        expectedKeyEpoch: 5,
        expectedMembershipManifestDigest: expectedDigest,
        operationId: _mutationId4,
        nextMembershipManifest: nextManifest,
        nextMembershipManifestDigest: nextDigest,
        envelope: envelope,
      ),
      rekeyOperationId: _mutationId5,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });
    final recoveryToken = CloudSyncAccountRecoveryToken.generate();

    final receiptFuture = client.commitRecoveryResume(
      recoveryToken: recoveryToken,
      request: request,
    );
    final httpRequest = await requestFuture;
    await utf8.decoder.bind(httpRequest).join();
    await _writeJsonResponse(httpRequest, <String, Object?>{
      'data': <String, Object?>{
        'result': 'replayed',
        'attemptId': _attemptId1,
        'status': 'resume-committed',
        'membershipOperationId': _mutationId4,
        'rekeyOperationId': _mutationId6,
        'generation': 5,
        'keyEpoch': 5,
        'nextAction': 'finish-first-data-rekey',
      },
    });

    await expectLater(
      receiptFuture,
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('安全控制面拒绝未知字段、历史串线与轮换错配回执', () async {
    final historyManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      91,
    );
    final stateData = _securityStateDataForTest(
      generation: 2,
      keyEpoch: 1,
      dataRekeyPhase: 'ready',
      membershipManifest: historyManifest,
      recoveryCapsuleVersion: 2,
      recoveryCapsule: _filledBytes(209, 92),
      operationId: _attemptId2,
    );
    final historyItem = <String, Object?>{
      ..._securityHistoryItemForTest(
        generation: 2,
        keyEpoch: 1,
        manifestSeed: 91,
        recoveryCapsuleVersion: 2,
        operationId: _attemptId2,
      ),
      'recoveryPublicKey': stateData['recoveryPublicKey'],
    };
    final nextManifest = _filledBytes(
      cloudSyncMembershipManifestMinimumBytes,
      93,
    );
    final rotation = CloudSyncDeviceRotationRequest(
      expectedGeneration: 2,
      expectedKeyEpoch: 1,
      expectedMembershipManifestDigest: CloudSyncMembershipManifestDigest.parse(
        _requiredTestString(stateData, 'membershipManifestDigest'),
      ),
      operationId: _mutationId3,
      revokeDeviceId: _deviceId2,
      nextMembershipManifest: nextManifest,
      nextRecoveryCapsuleVersion: 3,
      nextRecoveryCapsule: _filledBytes(213, 94),
      envelopes: <CloudSyncDeviceRotationEnvelope>[
        CloudSyncDeviceRotationEnvelope(
          targetDeviceId: _deviceId1,
          envelopeVersion: 1,
          keyEpoch: 2,
          accountKeyEnvelope: _filledBytes(
            cloudSyncAccountKeyEnvelopeBytes,
            95,
          ),
        ),
      ],
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      await request.drain<void>();
      final Object data = switch (request.uri.path) {
        '/api/device/security-state/get' => <String, Object?>{
          ...stateData,
          'unknownField': true,
        },
        '/api/device/security-state/history/list' => <String, Object?>{
          'items': <Object?>[historyItem],
          'afterGeneration': 1,
          'nextAfterGeneration': 2,
          'pageSize': 2,
          'hasMore': false,
          'currentState': _securityCurrentProjectionForTest(stateData),
        },
        '/api/device/rotation/commit' => <String, Object?>{
          'result': 'committed',
          'operationId': _mutationId2,
          'revokedDeviceId': rotation.revokeDeviceId,
          'fromGeneration': rotation.expectedGeneration,
          'generation': rotation.expectedGeneration + 1,
          'keyEpoch': rotation.expectedKeyEpoch + 1,
          'dataRekeyPhase': 'rekey-pending',
          'membershipManifestDigest':
              rotation.nextMembershipManifestDigest.encoded,
          'committedAt': '2026-07-29T05:01:00.000Z',
        },
        _ => throw StateError('未预期的请求路径：${request.uri.path}'),
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'data': data}));
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final invalidResponse = isA<CloudSyncException>().having(
      (error) => error.kind,
      'kind',
      CloudSyncFailureKind.invalidResponse,
    );

    await expectLater(client.getSecurityState(), throwsA(invalidResponse));
    await expectLater(
      client.listSecurityStateHistory(pageSize: 2),
      throwsA(invalidResponse),
    );
    await expectLater(
      client.commitDeviceRotation(rotation),
      throwsA(invalidResponse),
    );
    expect(
      () => client.listSecurityStateHistory(afterGeneration: -1),
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.validation,
        ),
      ),
    );
  });

  test('data-rekey 状态严格解析冻结范围与租约归属', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final stateFuture = client.getDataRekeyState();
    final request = await requestFuture;
    expect(request.method, 'GET');
    expect(request.uri.path, '/api/data-rekey/state/get');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer $_fullTokenValue',
    );
    expect(
      request.headers.value('x-kelivo-sync-protocol-version'),
      e2eeAccountRecordSyncProtocolVersion.toString(),
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'phase': 'rekey-pending',
          'dataGeneration': 4,
          'dataKeyEpoch': 2,
          'changeWatermark': 16,
          'operationId': _mutationId3,
          'targetKeyEpoch': 3,
          'sourceRecordCount': 1,
          'sourceAttachmentCount': 1,
          'sourceMaximumChangeSeq': 16,
          'sourceRecordCursorEnd': _recordId1,
          'sourceAttachmentCursorEnd': <String, Object?>{
            'attachmentId': _attachmentId,
            'uploadId': _uploadId,
          },
          'lease': <String, Object?>{
            'leaseVersion': 2,
            'ownedByCurrentDevice': true,
            'expiresAt': '2026-07-29T06:10:00.000Z',
          },
          'lastCompletion': null,
          'updatedAt': '2026-07-29T06:00:00.000Z',
        },
      }),
    );
    await request.response.close();

    final state = await stateFuture;
    expect(state, isA<CloudSyncDataRekeyPendingState>());
    final pending = state as CloudSyncDataRekeyPendingState;
    expect(pending.operationId, _mutationId3);
    expect(pending.sourceDataGeneration, 4);
    expect(pending.sourceKeyEpoch, 2);
    expect(pending.targetKeyEpoch, 3);
    expect(pending.sourceRecordCursorEnd, _recordId1);
    expect(pending.sourceAttachmentCursorEnd?.attachmentId, _attachmentId);
    expect(pending.sourceAttachmentCursorEnd?.uploadId, _uploadId);
    expect(pending.lease?.leaseVersion, 2);
    expect(pending.lease?.ownedByCurrentDevice, isTrue);
  });

  test('data-rekey 状态拒绝未知字段与冻结游标错配', () async {
    CloudSyncJsonMap pendingState({required int sourceRecordCount}) =>
        <String, Object?>{
          'phase': 'rekey-pending',
          'dataGeneration': 4,
          'dataKeyEpoch': 2,
          'changeWatermark': 16,
          'operationId': _mutationId3,
          'targetKeyEpoch': 3,
          'sourceRecordCount': sourceRecordCount,
          'sourceAttachmentCount': 0,
          'sourceMaximumChangeSeq': 16,
          'sourceRecordCursorEnd': _recordId1,
          'sourceAttachmentCursorEnd': null,
          'lease': null,
          'lastCompletion': null,
          'updatedAt': '2026-07-29T06:00:00.000Z',
        };

    final responses = <CloudSyncJsonMap>[
      <String, Object?>{
        ...pendingState(sourceRecordCount: 1),
        'unknownField': true,
      },
      pendingState(sourceRecordCount: 0),
      <String, Object?>{
        ...pendingState(sourceRecordCount: 1),
        'sourceMaximumChangeSeq': 15,
      },
    ];
    var responseIndex = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{'data': responses[responseIndex++]}),
      );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final invalidResponse = isA<CloudSyncException>().having(
      (error) => error.kind,
      'kind',
      CloudSyncFailureKind.invalidResponse,
    );

    await expectLater(client.getDataRekeyState(), throwsA(invalidResponse));
    await expectLater(client.getDataRekeyState(), throwsA(invalidResponse));
    await expectLater(client.getDataRekeyState(), throwsA(invalidResponse));
  });

  test('data-rekey 租约声明绑定稳定令牌与冻结范围', () async {
    final claimRequest = CloudSyncDataRekeyLeaseClaimRequest(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      mutationId: _mutationId5,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final claimFuture = client.claimDataRekeyLease(claimRequest);
    final request = await requestFuture;
    final body = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(request).join()),
    );
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/data-rekey/lease/claim');
    expect(body, <String, Object?>{
      'operationId': _mutationId3,
      'sourceDataGeneration': 4,
      'sourceKeyEpoch': 2,
      'targetKeyEpoch': 3,
      'leaseToken': _mutationId4,
      'mutationId': _mutationId5,
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'phase': 'rekey-pending',
          'operationId': _mutationId3,
          'sourceDataGeneration': 4,
          'sourceKeyEpoch': 2,
          'targetKeyEpoch': 3,
          'leaseVersion': 7,
          'leaseExpiresAt': '2026-07-29T06:10:00.000Z',
          'sourceRecordCount': 1,
          'sourceAttachmentCount': 1,
          'sourceMaximumChangeSeq': 16,
          'sourceRecordCursorEnd': _recordId1,
          'sourceAttachmentCursorEnd': <String, Object?>{
            'attachmentId': _attachmentId,
            'uploadId': _uploadId,
          },
        },
      }),
    );
    await request.response.close();

    final claim = await claimFuture;
    expect(claim.activeLease.operation, same(claimRequest.operation));
    expect(claim.activeLease.leaseToken, _mutationId4);
    expect(claim.activeLease.leaseVersion, 7);
    expect(claim.sourceRecordCount, 1);
    expect(claim.sourceAttachmentCount, 1);
    expect(claim.sourceMaximumChangeSeq, 16);
  });

  test('data-rekey 租约声明拒绝代次与错配回执', () async {
    expect(
      () => CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 4,
      ),
      throwsFormatException,
    );
    final claimRequest = CloudSyncDataRekeyLeaseClaimRequest(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      mutationId: _mutationId5,
    );
    CloudSyncJsonMap responseData() => <String, Object?>{
      'phase': 'rekey-pending',
      'operationId': _mutationId3,
      'sourceDataGeneration': 4,
      'sourceKeyEpoch': 2,
      'targetKeyEpoch': 3,
      'leaseVersion': 7,
      'leaseExpiresAt': '2026-07-29T06:10:00.000Z',
      'sourceRecordCount': 0,
      'sourceAttachmentCount': 0,
      'sourceMaximumChangeSeq': 16,
      'sourceRecordCursorEnd': null,
      'sourceAttachmentCursorEnd': null,
    };
    final responses = <CloudSyncJsonMap>[
      <String, Object?>{...responseData(), 'unknownField': true},
      <String, Object?>{...responseData(), 'operationId': _mutationId2},
    ];
    var responseIndex = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{'data': responses[responseIndex++]}),
      );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final invalidResponse = isA<CloudSyncException>().having(
      (error) => error.kind,
      'kind',
      CloudSyncFailureKind.invalidResponse,
    );

    await expectLater(
      client.claimDataRekeyLease(claimRequest),
      throwsA(invalidResponse),
    );
    await expectLater(
      client.claimDataRekeyLease(claimRequest),
      throwsA(invalidResponse),
    );
  });

  test('data-rekey 源记录分页发送租约范围并返回严格密文元数据', () async {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    final listRequest = CloudSyncDataRekeySourceRecordListRequest(
      activeLease: activeLease,
      afterRecordId: _recordId1,
      limit: 2,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pageFuture = client.listDataRekeySourceRecords(listRequest);
    final request = await requestFuture;
    final body = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(request).join()),
    );
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/data-rekey/source/record-list');
    expect(body, <String, Object?>{
      'operationId': _mutationId3,
      'sourceDataGeneration': 4,
      'sourceKeyEpoch': 2,
      'targetKeyEpoch': 3,
      'leaseToken': _mutationId4,
      'leaseVersion': 7,
      'afterRecordId': _recordId1,
      'limit': 2,
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'records': <Object?>[
            <String, Object?>{
              'recordId': _recordId2,
              'revision': 0xffffffff,
              'envelopeVersion': 1,
              'keyEpoch': 2,
              'ciphertext': _encodedBytes(3, 4),
              'ciphertextBytes': 3,
              'updatedAt': '2026-07-29T06:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
              'lastChangeSeq': 16,
              'kind': 'put',
              'ciphertextDigest': _encodedSha256(_filledBytes(3, 4)),
            },
          ],
          'nextAfterRecordId': null,
          'hasMore': false,
        },
      }),
    );
    await request.response.close();

    final page = await pageFuture;
    expect(page.records, hasLength(1));
    expect(page.records.single.recordId, _recordId2);
    expect(page.records.single.revision, 0xffffffff);
    expect(page.records.single.keyEpoch, 2);
    expect(page.records.single.ciphertext, <int>[4, 4, 4]);
    expect(
      page.records.single.ciphertextDigest,
      _sha256Bytes(_filledBytes(3, 4)),
    );
    expect(page.nextAfterRecordId, isNull);
    expect(page.hasMore, isFalse);
  });

  test('data-rekey 源附件分页保留分块代次并认证完整元数据', () async {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    final listRequest = CloudSyncDataRekeySourceAttachmentListRequest(
      activeLease: activeLease,
      limit: 2,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pageFuture = client.listDataRekeySourceAttachments(listRequest);
    final request = await requestFuture;
    final body = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(request).join()),
    );
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/data-rekey/source/attachment-list');
    expect(body, <String, Object?>{
      'operationId': _mutationId3,
      'sourceDataGeneration': 4,
      'sourceKeyEpoch': 2,
      'targetKeyEpoch': 3,
      'leaseToken': _mutationId4,
      'leaseVersion': 7,
      'limit': 2,
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'attachments': <Object?>[
            <String, Object?>{
              'attachmentId': _attachmentId,
              'uploadId': _uploadId,
              'chunkKeyEpoch': 1,
              'manifestKeyEpoch': 2,
              'manifestRevision': 9,
              'chunkCount': 2,
              'totalCiphertextBytes': 5,
              'manifestCiphertext': _encodedBytes(4, 6),
              'manifestCiphertextBytes': 4,
              'manifestCiphertextDigest': _encodedSha256(_filledBytes(4, 6)),
              'chunks': <Object?>[
                <String, Object?>{
                  'chunkIndex': 0,
                  'ciphertextBytes': 2,
                  'ciphertextDigest': _encodedBytes(32, 8),
                },
                <String, Object?>{
                  'chunkIndex': 1,
                  'ciphertextBytes': 3,
                  'ciphertextDigest': _encodedBytes(32, 9),
                },
              ],
              'committedAt': '2026-07-29T06:00:00.000Z',
            },
          ],
          'nextAfterAttachmentId': null,
          'nextAfterUploadId': null,
          'hasMore': false,
        },
      }),
    );
    await request.response.close();

    final page = await pageFuture;
    expect(page.attachments, hasLength(1));
    final attachment = page.attachments.single;
    expect(attachment.attachmentId, _attachmentId);
    expect(attachment.uploadId, _uploadId);
    expect(attachment.chunkKeyEpoch, 1);
    expect(attachment.manifestKeyEpoch, 2);
    expect(attachment.manifestRevision, 9);
    expect(attachment.manifestCiphertext, <int>[6, 6, 6, 6]);
    expect(attachment.chunks.map((chunk) => chunk.chunkIndex), <int>[0, 1]);
    expect(page.nextCursor, isNull);
    expect(page.hasMore, isFalse);
  });

  test('data-rekey 记录暂存绑定租约、源版本与幂等变更', () async {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    final stageRequest = CloudSyncDataRekeyRecordStageRequest(
      activeLease: activeLease,
      mutationId: _mutationId5,
      sourceRecordId: _recordId1,
      targetRecordId: _recordId2,
      sourceRevision: 9,
      ciphertext: _filledBytes(4, 10),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final resultFuture = client.stageDataRekeyRecord(stageRequest);
    final request = await requestFuture;
    final body = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(request).join()),
    );
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/data-rekey/record/stage');
    expect(body, <String, Object?>{
      'operationId': _mutationId3,
      'sourceDataGeneration': 4,
      'sourceKeyEpoch': 2,
      'targetKeyEpoch': 3,
      'leaseToken': _mutationId4,
      'leaseVersion': 7,
      'mutationId': _mutationId5,
      'sourceRecordId': _recordId1,
      'targetRecordId': _recordId2,
      'sourceRevision': 9,
      'envelopeVersion': 1,
      'ciphertext': _encodedBytes(4, 10),
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'result': 'staged',
          'operationId': _mutationId3,
          'mutationId': _mutationId5,
          'sourceRecordId': _recordId1,
          'targetRecordId': _recordId2,
          'leaseVersion': 7,
        },
      }),
    );
    await request.response.close();

    final result = await resultFuture;
    expect(result.mutationId, _mutationId5);
    expect(result.sourceRecordId, _recordId1);
    expect(result.targetRecordId, _recordId2);
    expect(result.leaseVersion, 7);
  });

  test('data-rekey 附件暂存仅提升 manifest 代次与版本', () async {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    final stageRequest = CloudSyncDataRekeyAttachmentStageRequest(
      activeLease: activeLease,
      mutationId: _mutationId5,
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      sourceManifestRevision: 9,
      manifestCiphertext: _filledBytes(4, 11),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final resultFuture = client.stageDataRekeyAttachment(stageRequest);
    final request = await requestFuture;
    final body = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(request).join()),
    );
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/data-rekey/attachment/stage');
    expect(body, <String, Object?>{
      'operationId': _mutationId3,
      'sourceDataGeneration': 4,
      'sourceKeyEpoch': 2,
      'targetKeyEpoch': 3,
      'leaseToken': _mutationId4,
      'leaseVersion': 7,
      'mutationId': _mutationId5,
      'attachmentId': _attachmentId,
      'uploadId': _uploadId,
      'sourceManifestRevision': 9,
      'manifestKeyEpoch': 3,
      'manifestRevision': 10,
      'manifestCiphertext': _encodedBytes(4, 11),
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'result': 'staged',
          'operationId': _mutationId3,
          'mutationId': _mutationId5,
          'attachmentId': _attachmentId,
          'uploadId': _uploadId,
          'manifestRevision': 10,
          'leaseVersion': 7,
        },
      }),
    );
    await request.response.close();

    final result = await resultFuture;
    expect(result.mutationId, _mutationId5);
    expect(result.attachmentId, _attachmentId);
    expect(result.uploadId, _uploadId);
    expect(result.manifestRevision, 10);
    expect(result.leaseVersion, 7);
  });

  test('data-rekey 最终提交绑定完整证明并严格解析完成回执', () async {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    final proof = CloudSyncDataRekeyFinalizeProof(
      issuerDeviceId: _deviceId1,
      sourceSnapshotRoot: _filledBytes(32, 12),
      sourceRecordCount: 1,
      sourceAttachmentCount: 1,
      sourceMaximumChangeSeq: 16,
      sourceRecordCursorEnd: _recordId1,
      sourceAttachmentCursorEnd: CloudSyncDataRekeyAttachmentCursor(
        attachmentId: _attachmentId,
        uploadId: _uploadId,
      ),
      membershipGeneration: 8,
      membershipManifestDigest: _filledBytes(32, 13),
      stagedRecordCount: 1,
      stagedAttachmentCount: 1,
      stagedCiphertextSetDigest: _filledBytes(32, 14),
      signature: _filledBytes(64, 15),
    );
    final finalizeRequest = CloudSyncDataRekeyFinalizeRequest(
      activeLease: activeLease,
      mutationId: _mutationId6,
      proof: proof,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final resultFuture = client.finalizeDataRekey(finalizeRequest);
    final request = await requestFuture;
    final body = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(request).join()),
    );
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/data-rekey/operation/finalize');
    expect(body, <String, Object?>{
      'operationId': _mutationId3,
      'sourceDataGeneration': 4,
      'sourceKeyEpoch': 2,
      'targetKeyEpoch': 3,
      'leaseToken': _mutationId4,
      'leaseVersion': 7,
      'mutationId': _mutationId6,
      'proof': <String, Object?>{
        'proofVersion': 2,
        'issuerDeviceId': _deviceId1,
        'targetDataGeneration': 5,
        'sourceSnapshotRoot': _encodedBytes(32, 12),
        'sourceRecordCount': 1,
        'sourceAttachmentCount': 1,
        'sourceMaximumChangeSeq': 16,
        'sourceRecordCursorEnd': _recordId1,
        'sourceAttachmentCursorEnd': <String, Object?>{
          'attachmentId': _attachmentId,
          'uploadId': _uploadId,
        },
        'membershipGeneration': 8,
        'membershipManifestDigest': _encodedBytes(32, 13),
        'stagedRecordCount': 1,
        'stagedAttachmentCount': 1,
        'stagedCiphertextSetDigest': _encodedBytes(32, 14),
        'signature': _encodedBytes(64, 15),
      },
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'result': 'finalized',
          'dataGeneration': 5,
          'dataKeyEpoch': 3,
          'changeWatermark': 18,
          'completion': <String, Object?>{
            'proofVersion': 2,
            'operationId': _mutationId3,
            'issuerDeviceId': _deviceId1,
            'sourceDataGeneration': 4,
            'targetDataGeneration': 5,
            'sourceKeyEpoch': 2,
            'targetKeyEpoch': 3,
            'sourceSnapshotRoot': _encodedBytes(32, 12),
            'sourceRecordCount': 1,
            'sourceAttachmentCount': 1,
            'sourceMaximumChangeSeq': 16,
            'sourceRecordCursorEnd': _recordId1,
            'sourceAttachmentCursorEnd': <String, Object?>{
              'attachmentId': _attachmentId,
              'uploadId': _uploadId,
            },
            'membershipGeneration': 8,
            'membershipManifestDigest': _encodedBytes(32, 13),
            'stagedRecordCount': 1,
            'stagedAttachmentCount': 1,
            'stagedCiphertextSetDigest': _encodedBytes(32, 14),
            'proofFrame': _encodedBytes(270, 16),
            'proofDigest': _encodedBytes(32, 17),
            'signature': _encodedBytes(64, 15),
            'finalizedAt': '2026-07-29T06:00:00.000Z',
          },
        },
      }),
    );
    await request.response.close();

    final outcome = await resultFuture;
    expect(outcome, isA<CloudSyncDataRekeyFinalizeResult>());
    final result = outcome as CloudSyncDataRekeyFinalizeResult;
    expect(result.dataGeneration, 5);
    expect(result.dataKeyEpoch, 3);
    expect(result.changeWatermark, 18);
    expect(result.completion.operationId, _mutationId3);
    expect(result.completion.signature, _filledBytes(64, 15));
  });

  test('data-rekey 最终提交严格解析跨请求校验进度', () async {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    final request = CloudSyncDataRekeyFinalizeRequest(
      activeLease: activeLease,
      mutationId: _mutationId6,
      proof: CloudSyncDataRekeyFinalizeProof(
        issuerDeviceId: _deviceId1,
        sourceSnapshotRoot: _filledBytes(32, 12),
        sourceRecordCount: 2,
        sourceAttachmentCount: 1,
        sourceMaximumChangeSeq: 16,
        sourceRecordCursorEnd: _recordId1,
        sourceAttachmentCursorEnd: CloudSyncDataRekeyAttachmentCursor(
          attachmentId: _attachmentId,
          uploadId: _uploadId,
        ),
        membershipGeneration: 8,
        membershipManifestDigest: _filledBytes(32, 13),
        stagedRecordCount: 2,
        stagedAttachmentCount: 1,
        stagedCiphertextSetDigest: _filledBytes(32, 14),
        signature: _filledBytes(64, 15),
      ),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final outcomeFuture = client.finalizeDataRekey(request);
    final httpRequest = await requestFuture;
    await httpRequest.drain<void>();
    httpRequest.response.headers.contentType = ContentType.json;
    httpRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'result': 'verification-pending',
          'operationId': _mutationId3,
          'phase': 'staged-records',
          'sourceRecordCount': 2,
          'sourceAttachmentCount': 1,
          'stagedRecordCount': 1,
          'stagedAttachmentCount': 0,
        },
      }),
    );
    await httpRequest.response.close();

    final outcome = await outcomeFuture;
    expect(outcome, isA<CloudSyncDataRekeyFinalizePending>());
    final pending = outcome as CloudSyncDataRekeyFinalizePending;
    expect(
      pending.phase,
      CloudSyncDataRekeyFinalizeVerificationPhase.stagedRecords,
    );
    expect(pending.stagedRecordCount, 1);
    expect(pending.stagedAttachmentCount, 0);
  });

  test('data-rekey 传输 DTO 在发网前拒绝非法边界', () {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    CloudSyncDataRekeyFinalizeProof proof({
      int sourceSnapshotRootBytes = 32,
      int sourceRecordCount = 0,
      int stagedRecordCount = 0,
      String? sourceRecordCursorEnd,
    }) {
      return CloudSyncDataRekeyFinalizeProof(
        issuerDeviceId: _deviceId1,
        sourceSnapshotRoot: _filledBytes(sourceSnapshotRootBytes),
        sourceRecordCount: sourceRecordCount,
        sourceAttachmentCount: 0,
        sourceMaximumChangeSeq: 0,
        sourceRecordCursorEnd: sourceRecordCursorEnd,
        sourceAttachmentCursorEnd: null,
        membershipGeneration: 1,
        membershipManifestDigest: _filledBytes(32),
        stagedRecordCount: stagedRecordCount,
        stagedAttachmentCount: 0,
        stagedCiphertextSetDigest: _filledBytes(32),
        signature: _filledBytes(64),
      );
    }

    expect(
      () => CloudSyncDataRekeySourceRecordListRequest(
        activeLease: activeLease,
        limit: 0,
      ),
      throwsFormatException,
    );
    expect(
      () => CloudSyncDataRekeyRecordStageRequest(
        activeLease: activeLease,
        mutationId: _mutationId5,
        sourceRecordId: _recordId1,
        targetRecordId: _recordId1,
        sourceRevision: 1,
        ciphertext: _filledBytes(1),
      ),
      throwsFormatException,
    );
    expect(
      () => CloudSyncDataRekeyAttachmentStageRequest(
        activeLease: activeLease,
        mutationId: _mutationId5,
        attachmentId: _attachmentId,
        uploadId: _uploadId,
        sourceManifestRevision: 0xffffffff,
        manifestCiphertext: _filledBytes(1),
      ),
      throwsFormatException,
    );
    expect(() => proof(sourceSnapshotRootBytes: 31), throwsFormatException);
    expect(
      () => proof(
        sourceRecordCount: 1,
        stagedRecordCount: 0,
        sourceRecordCursorEnd: _recordId1,
      ),
      throwsFormatException,
    );
    expect(
      () => proof(sourceRecordCount: 1, stagedRecordCount: 1),
      throwsFormatException,
    );
  });

  test('data-rekey 源记录分页拒绝未知字段和非法线格式', () async {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    final listRequest = CloudSyncDataRekeySourceRecordListRequest(
      activeLease: activeLease,
      limit: 2,
    );
    CloudSyncJsonMap record() => <String, Object?>{
      'recordId': _recordId1,
      'revision': 1,
      'envelopeVersion': 1,
      'keyEpoch': 2,
      'ciphertext': _encodedBytes(3, 1),
      'ciphertextBytes': 3,
      'updatedAt': '2026-07-29T06:00:00.000Z',
      'updatedByDeviceId': _deviceId1,
      'lastChangeSeq': 16,
      'kind': 'put',
      'ciphertextDigest': _encodedSha256(_filledBytes(3, 1)),
    };
    CloudSyncJsonMap page(CloudSyncJsonMap item) => <String, Object?>{
      'records': <Object?>[item],
      'nextAfterRecordId': null,
      'hasMore': false,
    };
    final responses = <CloudSyncJsonMap>[
      page(<String, Object?>{...record(), 'unknownField': true}),
      page(<String, Object?>{
        ...record(),
        'recordId': '10000000-0000-4000-8000-00000000000A',
      }),
      page(<String, Object?>{
        ...record(),
        'ciphertextDigest': '${_encodedSha256(_filledBytes(3, 1))}=',
      }),
      page(<String, Object?>{
        ...record(),
        'ciphertextDigest': _encodedBytes(32, 2),
      }),
      page(<String, Object?>{
        ...record(),
        'updatedAt': '2026-07-29T06:00:00.000+00:00',
      }),
      page(<String, Object?>{...record(), 'keyEpoch': 3}),
      <String, Object?>{
        'records': <Object?>[record()],
        'nextAfterRecordId': _recordId2,
        'hasMore': true,
      },
      page(<String, Object?>{...record(), 'revision': 0}),
    ];
    var responseIndex = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{'data': responses[responseIndex++]}),
      );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final invalidResponse = isA<CloudSyncException>().having(
      (error) => error.kind,
      'kind',
      CloudSyncFailureKind.invalidResponse,
    );

    for (var index = 0; index < responses.length; index++) {
      await expectLater(
        client.listDataRekeySourceRecords(listRequest),
        throwsA(invalidResponse),
      );
    }
  });

  test('data-rekey 源附件分页拒绝分块篡改与游标错配', () async {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    final listRequest = CloudSyncDataRekeySourceAttachmentListRequest(
      activeLease: activeLease,
      limit: 2,
    );
    CloudSyncJsonMap chunk() => <String, Object?>{
      'chunkIndex': 0,
      'ciphertextBytes': 3,
      'ciphertextDigest': _encodedBytes(32, 3),
    };
    CloudSyncJsonMap attachment() => <String, Object?>{
      'attachmentId': _attachmentId,
      'uploadId': _uploadId,
      'chunkKeyEpoch': 1,
      'manifestKeyEpoch': 2,
      'manifestRevision': 9,
      'chunkCount': 1,
      'totalCiphertextBytes': 3,
      'manifestCiphertext': _encodedBytes(4, 4),
      'manifestCiphertextBytes': 4,
      'manifestCiphertextDigest': _encodedSha256(_filledBytes(4, 4)),
      'chunks': <Object?>[chunk()],
      'committedAt': '2026-07-29T06:00:00.000Z',
    };
    CloudSyncJsonMap page(CloudSyncJsonMap item) => <String, Object?>{
      'attachments': <Object?>[item],
      'nextAfterAttachmentId': null,
      'nextAfterUploadId': null,
      'hasMore': false,
    };
    final responses = <CloudSyncJsonMap>[
      page(<String, Object?>{...attachment(), 'unknownField': true}),
      page(<String, Object?>{...attachment(), 'manifestKeyEpoch': 3}),
      page(<String, Object?>{...attachment(), 'chunkKeyEpoch': 0}),
      page(<String, Object?>{...attachment(), 'chunkKeyEpoch': 3}),
      page(<String, Object?>{
        ...attachment(),
        'chunks': <Object?>[
          <String, Object?>{...chunk(), 'chunkIndex': 1},
        ],
      }),
      page(<String, Object?>{
        ...attachment(),
        'manifestCiphertextDigest': _encodedBytes(32, 5),
      }),
      page(<String, Object?>{
        ...attachment(),
        'chunks': <Object?>[
          <String, Object?>{
            ...chunk(),
            'ciphertextDigest': '${_encodedBytes(32, 3)}=',
          },
        ],
      }),
      page(<String, Object?>{...attachment(), 'totalCiphertextBytes': 4}),
      page(<String, Object?>{
        ...attachment(),
        'committedAt': '2026-07-29T06:00:00.000+00:00',
      }),
      <String, Object?>{
        'attachments': <Object?>[attachment()],
        'nextAfterAttachmentId': _attachmentId,
        'nextAfterUploadId': null,
        'hasMore': true,
      },
    ];
    var responseIndex = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{'data': responses[responseIndex++]}),
      );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final invalidResponse = isA<CloudSyncException>().having(
      (error) => error.kind,
      'kind',
      CloudSyncFailureKind.invalidResponse,
    );

    for (var index = 0; index < responses.length; index++) {
      await expectLater(
        client.listDataRekeySourceAttachments(listRequest),
        throwsA(invalidResponse),
      );
    }
  });

  test('data-rekey 暂存回执拒绝未知字段与请求绑定错配', () async {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    final recordRequest = CloudSyncDataRekeyRecordStageRequest(
      activeLease: activeLease,
      mutationId: _mutationId5,
      sourceRecordId: _recordId1,
      targetRecordId: _recordId2,
      sourceRevision: 1,
      ciphertext: _filledBytes(1),
    );
    final attachmentRequest = CloudSyncDataRekeyAttachmentStageRequest(
      activeLease: activeLease,
      mutationId: _mutationId6,
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      sourceManifestRevision: 9,
      manifestCiphertext: _filledBytes(1),
    );
    CloudSyncJsonMap recordResult() => <String, Object?>{
      'result': 'staged',
      'operationId': _mutationId3,
      'mutationId': _mutationId5,
      'sourceRecordId': _recordId1,
      'targetRecordId': _recordId2,
      'leaseVersion': 7,
    };
    CloudSyncJsonMap attachmentResult() => <String, Object?>{
      'result': 'staged',
      'operationId': _mutationId3,
      'mutationId': _mutationId6,
      'attachmentId': _attachmentId,
      'uploadId': _uploadId,
      'manifestRevision': 10,
      'leaseVersion': 7,
    };
    final responses = <CloudSyncJsonMap>[
      <String, Object?>{...recordResult(), 'unknownField': true},
      <String, Object?>{...recordResult(), 'leaseVersion': 8},
      <String, Object?>{...attachmentResult(), 'unknownField': true},
      <String, Object?>{...attachmentResult(), 'manifestRevision': 9},
    ];
    var responseIndex = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{'data': responses[responseIndex++]}),
      );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final invalidResponse = isA<CloudSyncException>().having(
      (error) => error.kind,
      'kind',
      CloudSyncFailureKind.invalidResponse,
    );

    await expectLater(
      client.stageDataRekeyRecord(recordRequest),
      throwsA(invalidResponse),
    );
    await expectLater(
      client.stageDataRekeyRecord(recordRequest),
      throwsA(invalidResponse),
    );
    await expectLater(
      client.stageDataRekeyAttachment(attachmentRequest),
      throwsA(invalidResponse),
    );
    await expectLater(
      client.stageDataRekeyAttachment(attachmentRequest),
      throwsA(invalidResponse),
    );
  });

  test('data-rekey 最终回执拒绝证明篡改与目标状态错配', () async {
    final activeLease = CloudSyncDataRekeyActiveLease(
      operation: CloudSyncDataRekeyOperationScope(
        operationId: _mutationId3,
        sourceDataGeneration: 4,
        sourceKeyEpoch: 2,
        targetKeyEpoch: 3,
      ),
      leaseToken: _mutationId4,
      leaseVersion: 7,
    );
    final proof = CloudSyncDataRekeyFinalizeProof(
      issuerDeviceId: _deviceId1,
      sourceSnapshotRoot: _filledBytes(32, 12),
      sourceRecordCount: 0,
      sourceAttachmentCount: 0,
      sourceMaximumChangeSeq: 16,
      sourceRecordCursorEnd: null,
      sourceAttachmentCursorEnd: null,
      membershipGeneration: 8,
      membershipManifestDigest: _filledBytes(32, 13),
      stagedRecordCount: 0,
      stagedAttachmentCount: 0,
      stagedCiphertextSetDigest: _filledBytes(32, 14),
      signature: _filledBytes(64, 15),
    );
    final finalizeRequest = CloudSyncDataRekeyFinalizeRequest(
      activeLease: activeLease,
      mutationId: _mutationId6,
      proof: proof,
    );
    CloudSyncJsonMap completion() => <String, Object?>{
      'proofVersion': 2,
      'operationId': _mutationId3,
      'issuerDeviceId': _deviceId1,
      'sourceDataGeneration': 4,
      'targetDataGeneration': 5,
      'sourceKeyEpoch': 2,
      'targetKeyEpoch': 3,
      'sourceSnapshotRoot': _encodedBytes(32, 12),
      'sourceRecordCount': 0,
      'sourceAttachmentCount': 0,
      'sourceMaximumChangeSeq': 16,
      'sourceRecordCursorEnd': null,
      'sourceAttachmentCursorEnd': null,
      'membershipGeneration': 8,
      'membershipManifestDigest': _encodedBytes(32, 13),
      'stagedRecordCount': 0,
      'stagedAttachmentCount': 0,
      'stagedCiphertextSetDigest': _encodedBytes(32, 14),
      'proofFrame': _encodedBytes(270, 16),
      'proofDigest': _encodedBytes(32, 17),
      'signature': _encodedBytes(64, 15),
      'finalizedAt': '2026-07-29T06:00:00.000Z',
    };
    CloudSyncJsonMap result(CloudSyncJsonMap proofResult) => <String, Object?>{
      'result': 'finalized',
      'dataGeneration': 5,
      'dataKeyEpoch': 3,
      'changeWatermark': 18,
      'completion': proofResult,
    };
    final responses = <CloudSyncJsonMap>[
      <String, Object?>{...result(completion()), 'unknownField': true},
      <String, Object?>{...result(completion()), 'dataGeneration': 6},
      <String, Object?>{...result(completion()), 'changeWatermark': 15},
      result(<String, Object?>{...completion(), 'operationId': _mutationId2}),
      result(<String, Object?>{
        ...completion(),
        'signature': _encodedBytes(64, 18),
      }),
      result(<String, Object?>{
        ...completion(),
        'proofFrame': _encodedBytes(269, 16),
      }),
      result(<String, Object?>{
        ...completion(),
        'finalizedAt': '2026-07-29T06:00:00.000+00:00',
      }),
    ];
    var responseIndex = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{'data': responses[responseIndex++]}),
      );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final invalidResponse = isA<CloudSyncException>().having(
      (error) => error.kind,
      'kind',
      CloudSyncFailureKind.invalidResponse,
    );

    for (var index = 0; index < responses.length; index++) {
      await expectLater(
        client.finalizeDataRekey(finalizeRequest),
        throwsA(invalidResponse),
      );
    }
  });

  test('持久账户会话恢复认证会话时保留设备密钥版本', () {
    final persisted = _accountKeyLeaseSession(
      baseUrl: defaultCloudSyncBaseUrl,
      loginName: 'roundtrip-user',
      deviceKeyVersion: 9,
    );

    final authenticated = persisted.toAuthenticatedSession();

    expect(authenticated.token, same(persisted.token));
    expect(authenticated.keyEpoch, persisted.keyEpoch);
    expect(authenticated.user.id, persisted.userId);
    expect(authenticated.device.id, persisted.deviceId);
    expect(authenticated.deviceKeyVersion, 9);
  });

  test('OPAQUE 注册开始规范化账户字段并保持固定长度二进制', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final startFuture = client.startOpaqueRegistration(
      loginName: ' Alice ',
      displayName: ' Alice ',
      device: _deviceIdentity(),
      registrationRequest: _filledBytes(
        cloudSyncOpaqueRegistrationRequestBytes,
        3,
      ),
    );

    final request = await requestFuture;
    expect(request.uri.path, '/api/auth/opaque-registration/start');
    expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
    expect(jsonDecode(await utf8.decoder.bind(request).join()), <
      String,
      Object?
    >{
      'protocolVersion': cloudSyncOpaqueProtocolVersion,
      'loginName': 'alice',
      'displayName': 'Alice',
      'deviceId': _deviceId1,
      'deviceName': 'Windows 主机',
      'platform': 'windows',
      'clientVersion': '1.2.3',
      'deviceKeyVersion': 1,
      'signingPublicKey': _encodedBytes(cloudSyncDevicePublicKeyBytes, 1),
      'keyAgreementPublicKey': _encodedBytes(cloudSyncDevicePublicKeyBytes, 2),
      'registrationRequest': _encodedBytes(
        cloudSyncOpaqueRegistrationRequestBytes,
        3,
      ),
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'attemptId': _attemptId1,
          'userId': _userId,
          'accountBinding': _accountContextId,
          'deviceChallenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 6),
          'registrationResponse': _encodedBytes(
            cloudSyncOpaqueRegistrationResponseBytes,
            7,
          ),
          'expiresAt': '2026-07-26T05:05:00.000Z',
        },
      }),
    );
    await request.response.close();

    final result = await startFuture;
    expect(result.attemptId, _attemptId1);
    expect(result.userId, _userId);
    expect(result.accountBinding, _accountContextId);
    expect(result.deviceChallenge, everyElement(6));
    expect(result.registrationResponse, everyElement(7));
  });

  test('OPAQUE 注册完成返回绑定当前 keyEpoch 的完整会话', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final finishFuture = client.finishOpaqueRegistration(
      attemptId: _attemptId1,
      registrationUpload: _filledBytes(
        cloudSyncOpaqueRegistrationUploadBytes,
        8,
      ),
      accountKeyEnvelope: _filledBytes(cloudSyncAccountKeyEnvelopeBytes, 9),
      securityState: _genesisSecurityState(),
      deviceProof: _filledBytes(cloudSyncDeviceProofBytes, 10),
    );

    final request = await requestFuture;
    expect(request.uri.path, '/api/auth/opaque-registration/finish');
    expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
    expect(jsonDecode(await utf8.decoder.bind(request).join()), <
      String,
      Object?
    >{
      'protocolVersion': cloudSyncOpaqueProtocolVersion,
      'attemptId': _attemptId1,
      'registrationUpload': _encodedBytes(
        cloudSyncOpaqueRegistrationUploadBytes,
        8,
      ),
      'accountKeyEnvelope': _encodedBytes(cloudSyncAccountKeyEnvelopeBytes, 9),
      'securityState': <String, Object?>{
        'generation': 1,
        'operationId': _attemptId1,
        'keyEpoch': 1,
        'membershipManifest': _encodedBytes(
          cloudSyncMembershipManifestMinimumBytes,
          30,
        ),
        'membershipManifestDigest':
            _genesisSecurityState().membershipManifestDigest.encoded,
        'recoveryPublicKeyVersion': 1,
        'recoveryPublicKey': _encodedBytes(cloudSyncRecoveryPublicKeyBytes, 31),
        'recoveryCapsuleVersion': 1,
        'recoveryCapsule': _encodedBytes(cloudSyncRecoveryCapsuleBytes, 32),
      },
      'deviceProof': _encodedBytes(cloudSyncDeviceProofBytes, 10),
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{'data': _registrationAuthenticatedData()}),
    );
    await request.response.close();

    final session = await finishFuture;
    expect(session.token.value, _fullTokenValue);
    expect(session.keyEpoch, 1);
    expect(session.user.id, _userId);
    expect(session.device.id, _deviceId1);
    expect(session.device.status, CloudSyncAuthenticatedDeviceStatus.active);
    expect(session.deviceKeyVersion, isNull);
  });

  test('OPAQUE 登录保持匿名并区分已认证与待设备批准结果', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <(String, String?, CloudSyncJsonMap)>[];
    final subscription = server.listen((request) async {
      final body = copyCloudSyncJsonMap(
        jsonDecode(await utf8.decoder.bind(request).join()),
      );
      requests.add((
        request.uri.path,
        request.headers.value(HttpHeaders.authorizationHeader),
        body,
      ));
      final Object data;
      if (request.uri.path == '/api/auth/opaque-login/start') {
        data = <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'attemptId': _attemptId1,
          'accountBinding': _accountContextId,
          'deviceChallenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 11),
          'credentialResponse': _encodedBytes(
            cloudSyncOpaqueCredentialResponseBytes,
            12,
          ),
          'expiresAt': '2026-07-26T05:05:00.000Z',
        };
      } else if (body['attemptId'] == _attemptId1) {
        data = _authenticatedData(keyEpoch: 12);
      } else {
        data = <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'result': 'device-approval-required',
          'onboardingToken': _onboardingTokenValue,
          'onboardingTokenExpiresAt': '2026-07-26T05:05:00.000Z',
          'device': <String, Object?>{
            'id': _deviceId2,
            'name': 'Windows 主机',
            'platform': 'windows',
            'clientVersion': '1.2.3',
            'authGeneration': 0,
            'status': 'pending',
            'createdAt': '2026-07-26T05:00:00.000Z',
          },
        };
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'data': data}));
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final start = await client.startOpaqueLogin(
      loginName: ' Alice ',
      device: _deviceIdentity(),
      credentialRequest: _filledBytes(
        cloudSyncOpaqueCredentialRequestBytes,
        13,
      ),
    );
    final authenticated = await client.finishOpaqueLogin(
      attemptId: _attemptId1,
      credentialFinalization: _filledBytes(
        cloudSyncOpaqueCredentialFinalizationBytes,
        14,
      ),
      deviceProof: _filledBytes(cloudSyncDeviceProofBytes, 15),
    );
    final approvalRequired = await client.finishOpaqueLogin(
      attemptId: _attemptId2,
      credentialFinalization: _filledBytes(
        cloudSyncOpaqueCredentialFinalizationBytes,
        16,
      ),
      deviceProof: _filledBytes(cloudSyncDeviceProofBytes, 17),
    );

    expect(start.credentialResponse, everyElement(12));
    expect(
      authenticated,
      isA<CloudSyncOpaqueLoginAuthenticated>().having(
        (result) => result.session.keyEpoch,
        'keyEpoch',
        12,
      ),
    );
    expect(
      approvalRequired,
      isA<CloudSyncOpaqueLoginApprovalRequired>()
          .having(
            (result) => result.onboardingToken.value,
            'onboardingToken',
            _onboardingTokenValue,
          )
          .having(
            (result) => result.device.status,
            'device.status',
            CloudSyncAuthenticatedDeviceStatus.pending,
          ),
    );
    expect(requests, hasLength(3));
    expect(requests.map((request) => request.$2), everyElement(isNull));
    expect(requests.first.$3['loginName'], 'alice');
    expect(
      requests.first.$3['credentialRequest'],
      _encodedBytes(cloudSyncOpaqueCredentialRequestBytes, 13),
    );
  });

  test('桌面待批准登录创建绑定当前设备身份的二维码并可取消', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final transportBaseUrl = 'http://${server.address.address}:${server.port}';
    final serviceBaseUrl = 'https://pairing-target-${server.port}.example';
    const loginName = 'pairing-target';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final key = await core.createSlot(
      _authenticatorSlotId(serviceBaseUrl, loginName),
    );
    final identity = await core.generateDeviceIdentity();
    final publicKeys = await core.readDevicePublicKeys(identity);
    final identityState = await core.sealDeviceState(
      key,
      identity,
      deviceId: _rawUuid(_deviceId2),
      keyVersion: 1,
    );
    await store.write(
      normalizedBaseUrl: serviceBaseUrl,
      normalizedLoginName: loginName,
      blob: identityState,
    );
    await core.closeDeviceIdentity(identity);
    await core.close(key);

    final client = CloudSyncClient.forTesting(baseUrl: transportBaseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: serviceBaseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      await requests.cancel();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final onboardingExpiresAt = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
      isUtc: true,
    );
    final approvalRequired = E2eeAccountLoginApprovalRequired(
      onboardingToken: _onboardingToken,
      onboardingTokenExpiresAt: onboardingExpiresAt,
      loginName: loginName,
      device: CloudSyncAuthenticatedDevice(
        id: _deviceId2,
        name: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
        status: CloudSyncAuthenticatedDeviceStatus.pending,
        createdAt: DateTime.utc(2026, 7, 26, 5),
      ),
    );
    Future<String> respondToCreate(DateTime expiresAt) async {
      expect(await requests.moveNext(), isTrue);
      final createRequest = requests.current;
      final createBody = copyCloudSyncJsonMap(
        jsonDecode(await utf8.decoder.bind(createRequest).join()),
      );
      expect(createRequest.uri.path, '/api/auth/device-pairing/create');
      final pairingId = createBody['pairingId']! as String;
      createRequest.response.headers.contentType = ContentType.json;
      createRequest.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'protocolVersion': cloudSyncOpaqueProtocolVersion,
            'pairingId': pairingId,
            'accountContextId': _userId,
            'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
            'expiresAt': expiresAt.toIso8601String(),
            'targetDevice': <String, Object?>{
              'id': _deviceId2,
              'name': 'Windows 主机',
              'platform': 'windows',
              'clientVersion': '1.2.3',
              'keyVersion': 1,
              'authGeneration': 0,
              'signingPublicKey': base64Url
                  .encode(publicKeys.signingPublicKey)
                  .replaceAll('=', ''),
              'keyAgreementPublicKey': base64Url
                  .encode(publicKeys.keyAgreementPublicKey)
                  .replaceAll('=', ''),
            },
          },
        }),
      );
      await createRequest.response.close();
      return pairingId;
    }

    final pairingExpiresAt = onboardingExpiresAt.subtract(
      const Duration(seconds: 1),
    );
    final startFuture = authenticator.startDevicePairing(approvalRequired);
    final pairingId = await respondToCreate(pairingExpiresAt);

    final pending = await startFuture;
    final frame = pending.takeQrFrame(now: DateTime.now().toUtc());
    final decoded = CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
      frame,
      now: DateTime.now().toUtc(),
    );
    expect(decoded.pairingId, pairingId);
    expect(decoded.accountContextId, _userId);
    expect(decoded.targetDeviceId, _deviceId2);
    decoded.dispose();

    final foreignClient = CloudSyncClient.forTesting(baseUrl: transportBaseUrl);
    final foreignAuthenticator = E2eeAccountAuthenticator(
      baseUrl: serviceBaseUrl,
      accountClient: foreignClient,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() => foreignClient.close(force: true));
    await expectLater(
      foreignAuthenticator.waitForDevicePairing(pending),
      throwsStateError,
    );
    await expectLater(
      foreignAuthenticator.cancelDevicePairing(pending),
      throwsStateError,
    );

    final waitingFuture = authenticator.waitForDevicePairing(pending);
    expect(await requests.moveNext(), isTrue);
    final queryRequest = requests.current;
    expect(queryRequest.uri.path, '/api/auth/device-pairing/query');
    await utf8.decoder.bind(queryRequest).join();
    final waitingExpectation = expectLater(
      waitingFuture,
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.cancelled,
        ),
      ),
    );

    final cancelFuture = pending.cancel();
    expect(identical(pending.cancel(), cancelFuture), isTrue);
    expect(await requests.moveNext(), isTrue);
    final cancelRequest = requests.current;
    expect(cancelRequest.uri.path, '/api/auth/device-pairing/cancel');
    await waitingExpectation;
    final cancelSocket = await cancelRequest.response.detachSocket();
    cancelSocket.destroy();
    await expectLater(cancelFuture, throwsA(isA<CloudSyncException>()));
    await expectLater(pending.cancel(), throwsA(isA<CloudSyncException>()));
    queryRequest.response.headers.contentType = ContentType.json;
    queryRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': pairingId,
          'accountContextId': _userId,
          'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
          'expiresAt': pairingExpiresAt.toIso8601String(),
          'targetDevice': <String, Object?>{
            'id': _deviceId2,
            'name': 'Windows 主机',
            'platform': 'windows',
            'clientVersion': '1.2.3',
            'keyVersion': 1,
            'authGeneration': 0,
            'signingPublicKey': base64Url
                .encode(publicKeys.signingPublicKey)
                .replaceAll('=', ''),
            'keyAgreementPublicKey': base64Url
                .encode(publicKeys.keyAgreementPublicKey)
                .replaceAll('=', ''),
          },
          'status': 'pending',
        },
      }),
    );
    await queryRequest.response.close();

    final rejectedStart = authenticator.startDevicePairing(approvalRequired);
    await respondToCreate(onboardingExpiresAt.add(const Duration(seconds: 1)));
    await expectLater(rejectedStart, throwsStateError);
  });

  test('移动可信设备在签名成员清单接入前拒绝批准并清零扫码帧', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final transportBaseUrl = 'http://${server.address.address}:${server.port}';
    final serviceBaseUrl = 'https://pairing-issuer-${server.port}.example';
    const loginName = 'pairing-issuer';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final key = await core.createSlot(
      _authenticatorSlotId(serviceBaseUrl, loginName),
    );
    final identity = await core.generateDeviceIdentity();
    final ark = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 7,
    );
    final targetIdentity = await core.generateDeviceIdentity();
    final targetPublicKeys = await core.readDevicePublicKeys(targetIdentity);
    final fullState = await core.sealDeviceState(
      key,
      identity,
      deviceId: _rawUuid(_issuerDeviceId),
      keyVersion: 1,
      ark: ark,
      account: KelivoDeviceStateAccountBinding(
        userId: _rawUuid(_userId),
        keyEpoch: 7,
      ),
    );
    await store.write(
      normalizedBaseUrl: serviceBaseUrl,
      normalizedLoginName: loginName,
      blob: fullState,
    );
    await core.closeAccountRootKey(ark);
    await core.closeDeviceIdentity(targetIdentity);
    await core.closeDeviceIdentity(identity);
    await core.close(key);

    final client = CloudSyncClient.forTesting(baseUrl: transportBaseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: serviceBaseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      await requests.cancel();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().toUtc().millisecondsSinceEpoch,
      isUtc: true,
    );
    final qrPayload = _pairingQrPayload(
      pairingSecret: _filledBytes(cloudSyncPairingSecretBytes, 24),
      now: now,
      expiresAt: now.add(const Duration(minutes: 4)),
      normalizedServiceOrigin: serviceBaseUrl,
      signingPublicKey: targetPublicKeys.signingPublicKey,
      keyAgreementPublicKey: targetPublicKeys.keyAgreementPublicKey,
    );
    final qrFrame = CloudSyncDevicePairingQrCodec.encode(qrPayload, now: now);
    qrPayload.dispose();
    final session = CloudSyncAuthenticatedSession(
      token: _fullToken,
      tokenExpiresAt: now.add(const Duration(minutes: 10)),
      keyEpoch: 7,
      authGeneration: 3,
      sessionGeneration: 4,
      user: CloudSyncAuthenticatedUser(
        id: _userId,
        loginName: loginName,
        displayName: 'Pairing Issuer',
        role: CloudSyncUserRole.owner,
        attachmentQuotaBytes: 1048576,
      ),
      device: CloudSyncAuthenticatedDevice(
        id: _issuerDeviceId,
        name: 'Android 手机',
        platform: CloudSyncPlatform.android,
        clientVersion: '1.2.3',
        status: CloudSyncAuthenticatedDeviceStatus.active,
        createdAt: now,
      ),
    );

    await expectLater(
      authenticator.approveScannedDevicePairing(
        loginName: loginName,
        session: session,
        qrFrame: qrFrame,
      ),
      throwsUnsupportedError,
    );
    expect(qrFrame, everyElement(0));

    Uint8List createQrFrame({
      required int secretByte,
      String accountContextId = _userId,
    }) {
      final payload = _pairingQrPayload(
        pairingSecret: _filledBytes(cloudSyncPairingSecretBytes, secretByte),
        now: now,
        expiresAt: now.add(const Duration(minutes: 4)),
        normalizedServiceOrigin: serviceBaseUrl,
        accountContextId: accountContextId,
        signingPublicKey: targetPublicKeys.signingPublicKey,
        keyAgreementPublicKey: targetPublicKeys.keyAgreementPublicKey,
      );
      try {
        return CloudSyncDevicePairingQrCodec.encode(payload, now: now);
      } finally {
        payload.dispose();
      }
    }

    final crossAccountFrame = createQrFrame(
      secretByte: 25,
      accountContextId: _accountContextId,
    );
    await expectLater(
      authenticator.approveScannedDevicePairing(
        loginName: loginName,
        session: session,
        qrFrame: crossAccountFrame,
      ),
      throwsFormatException,
    );
    expect(crossAccountFrame, everyElement(0));

    final desktopFrame = createQrFrame(secretByte: 26);
    final desktopSession = CloudSyncAuthenticatedSession(
      token: _fullToken,
      tokenExpiresAt: session.tokenExpiresAt,
      keyEpoch: session.keyEpoch,
      authGeneration: session.authGeneration,
      sessionGeneration: session.sessionGeneration,
      user: session.user,
      device: CloudSyncAuthenticatedDevice(
        id: session.device.id,
        name: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: session.device.clientVersion,
        status: CloudSyncAuthenticatedDeviceStatus.active,
        createdAt: session.device.createdAt,
      ),
    );
    await expectLater(
      authenticator.approveScannedDevicePairing(
        loginName: loginName,
        session: desktopSession,
        qrFrame: desktopFrame,
      ),
      throwsUnsupportedError,
    );
    expect(desktopFrame, everyElement(0));
  });

  test('桌面接收批准后先持久化完整状态与恢复事务再消费', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final transportBaseUrl = 'http://${server.address.address}:${server.port}';
    final serviceBaseUrl = 'https://pairing-consumer-${server.port}.example';
    const loginName = 'pairing-consumer';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final key = await core.createSlot(
      _authenticatorSlotId(serviceBaseUrl, loginName),
    );
    final targetIdentity = await core.generateDeviceIdentity();
    final targetPublicKeys = await core.readDevicePublicKeys(targetIdentity);
    final identityState = await core.sealDeviceState(
      key,
      targetIdentity,
      deviceId: _rawUuid(_deviceId2),
      keyVersion: 1,
    );
    await store.write(
      normalizedBaseUrl: serviceBaseUrl,
      normalizedLoginName: loginName,
      blob: identityState,
    );
    await core.closeDeviceIdentity(targetIdentity);
    await core.close(key);

    final client = CloudSyncClient.forTesting(baseUrl: transportBaseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: serviceBaseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      await requests.cancel();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().toUtc().millisecondsSinceEpoch,
      isUtc: true,
    );
    final pairingExpiresAt = now.add(const Duration(minutes: 4));
    final approvalRequired = E2eeAccountLoginApprovalRequired(
      onboardingToken: _onboardingToken,
      onboardingTokenExpiresAt: now.add(const Duration(minutes: 5)),
      loginName: loginName,
      device: CloudSyncAuthenticatedDevice(
        id: _deviceId2,
        name: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
        status: CloudSyncAuthenticatedDeviceStatus.pending,
        createdAt: now,
      ),
    );
    final startFuture = authenticator.startDevicePairing(approvalRequired);
    expect(await requests.moveNext(), isTrue);
    final createRequest = requests.current;
    final createBody = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(createRequest).join()),
    );
    final pairingId = createBody['pairingId']! as String;
    createRequest.response.headers.contentType = ContentType.json;
    createRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': pairingId,
          'accountContextId': _userId,
          'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
          'expiresAt': pairingExpiresAt.toIso8601String(),
          'targetDevice': <String, Object?>{
            'id': _deviceId2,
            'name': 'Windows 主机',
            'platform': 'windows',
            'clientVersion': '1.2.3',
            'keyVersion': 1,
            'authGeneration': 0,
            'signingPublicKey': base64Url
                .encode(targetPublicKeys.signingPublicKey)
                .replaceAll('=', ''),
            'keyAgreementPublicKey': base64Url
                .encode(targetPublicKeys.keyAgreementPublicKey)
                .replaceAll('=', ''),
          },
        },
      }),
    );
    await createRequest.response.close();
    final pending = await startFuture;

    final frame = pending.takeQrFrame(now: now);
    final decoded = CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
      frame,
      now: now,
    );
    final pairingSecret = decoded.takePairingSecret();
    decoded.dispose();
    final issuerIdentity = await core.generateDeviceIdentity();
    final issuerArk = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 1,
    );
    final issuerPublicKeys = await core.readDevicePublicKeys(issuerIdentity);
    final alternateIssuerIdentity = await core.generateDeviceIdentity();
    final alternateIssuerPublicKeys = await core.readDevicePublicKeys(
      alternateIssuerIdentity,
    );
    final recoveryPublicKey = _filledBytes(
      cloudSyncRecoveryPublicKeyBytes,
      0x61,
    );
    final recoveryCapsule = _filledBytes(cloudSyncRecoveryCapsuleBytes, 0x62);
    late final KelivoPairingApprovalBundle approvalBundle;
    late final E2eeVerifiedMembership pairedMembership;
    late final E2eeVerifiedMembership alternateIssuerMembership;
    try {
      approvalBundle = await core.createPairingApproval(
        issuerIdentity,
        issuerArk,
        pairingId: _rawUuid(pairingId),
        userId: _rawUuid(_userId),
        issuerDeviceId: _rawUuid(_issuerDeviceId),
        targetDeviceId: _rawUuid(_deviceId2),
        expiresAtMs: pairingExpiresAt.millisecondsSinceEpoch,
        challenge: _filledBytes(cloudSyncDeviceChallengeBytes, 18),
        keyEpoch: 1,
        targetPublicKeys: targetPublicKeys,
        pairingSecret: pairingSecret,
      );
      final initialMembership = await const E2eeAccountTrustManifestModule()
          .create(
            ark: issuerArk,
            change: E2eeInitializeMembershipChange(
              userId: _userId,
              operationId: _attemptId2,
              member: E2eeMembershipDeviceInput(
                deviceId: _issuerDeviceId,
                keyVersion: 1,
                authGeneration: 0,
                signingPublicKey: issuerPublicKeys.signingPublicKey,
                keyAgreementPublicKey: issuerPublicKeys.keyAgreementPublicKey,
              ),
              recoveryPublicKeyVersion: 1,
              recoveryPublicKey: recoveryPublicKey,
              recoveryCapsuleVersion: 1,
              recoveryCapsule: recoveryCapsule,
            ),
          );
      pairedMembership = await const E2eeAccountTrustManifestModule().create(
        ark: issuerArk,
        change: E2eeAddDeviceMembershipChange(
          previous: initialMembership,
          pairingId: pairingId,
          issuerDeviceId: _issuerDeviceId,
          subject: E2eeMembershipDeviceInput(
            deviceId: _deviceId2,
            keyVersion: 1,
            authGeneration: 1,
            signingPublicKey: targetPublicKeys.signingPublicKey,
            keyAgreementPublicKey: targetPublicKeys.keyAgreementPublicKey,
          ),
        ),
      );
      final alternateInitialMembership =
          await const E2eeAccountTrustManifestModule().create(
            ark: issuerArk,
            change: E2eeInitializeMembershipChange(
              userId: _userId,
              operationId: _attemptId2,
              member: E2eeMembershipDeviceInput(
                deviceId: _issuerDeviceId,
                keyVersion: 1,
                authGeneration: 0,
                signingPublicKey: alternateIssuerPublicKeys.signingPublicKey,
                keyAgreementPublicKey:
                    alternateIssuerPublicKeys.keyAgreementPublicKey,
              ),
              recoveryPublicKeyVersion: 1,
              recoveryPublicKey: recoveryPublicKey,
              recoveryCapsuleVersion: 1,
              recoveryCapsule: recoveryCapsule,
            ),
          );
      alternateIssuerMembership = await const E2eeAccountTrustManifestModule()
          .create(
            ark: issuerArk,
            change: E2eeAddDeviceMembershipChange(
              previous: alternateInitialMembership,
              pairingId: pairingId,
              issuerDeviceId: _issuerDeviceId,
              subject: E2eeMembershipDeviceInput(
                deviceId: _deviceId2,
                keyVersion: 1,
                authGeneration: 1,
                signingPublicKey: targetPublicKeys.signingPublicKey,
                keyAgreementPublicKey: targetPublicKeys.keyAgreementPublicKey,
              ),
            ),
          );
    } finally {
      pairingSecret.fillRange(0, pairingSecret.length, 0);
      await core.closeAccountRootKey(issuerArk);
      await core.closeDeviceIdentity(issuerIdentity);
      await core.closeDeviceIdentity(alternateIssuerIdentity);
    }

    final completionFuture = authenticator.waitForDevicePairing(pending);
    expect(await requests.moveNext(), isTrue);
    final queryRequest = requests.current;
    expect(queryRequest.uri.path, '/api/auth/device-pairing/query');
    await utf8.decoder.bind(queryRequest).join();
    queryRequest.response.headers.contentType = ContentType.json;
    queryRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': pairingId,
          'accountContextId': _userId,
          'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
          'expiresAt': pairingExpiresAt.toIso8601String(),
          'targetDevice': <String, Object?>{
            'id': _deviceId2,
            'name': 'Windows 主机',
            'platform': 'windows',
            'clientVersion': '1.2.3',
            'keyVersion': 1,
            'authGeneration': 0,
            'signingPublicKey': base64Url
                .encode(targetPublicKeys.signingPublicKey)
                .replaceAll('=', ''),
            'keyAgreementPublicKey': base64Url
                .encode(targetPublicKeys.keyAgreementPublicKey)
                .replaceAll('=', ''),
          },
          'status': 'approved',
          'issuerDeviceId': _issuerDeviceId,
          'issuerKeyVersion': 1,
          'issuerAuthGeneration': 0,
          'issuerSigningPublicKey': base64Url
              .encode(issuerPublicKeys.signingPublicKey)
              .replaceAll('=', ''),
          'issuerKeyAgreementPublicKey': base64Url
              .encode(issuerPublicKeys.keyAgreementPublicKey)
              .replaceAll('=', ''),
          'keyEpoch': 1,
          'accountKeyEnvelope': base64Url
              .encode(approvalBundle.envelope)
              .replaceAll('=', ''),
          'deviceProof': base64Url
              .encode(approvalBundle.signature)
              .replaceAll('=', ''),
          'pairingAuthenticator': base64Url
              .encode(approvalBundle.authenticator)
              .replaceAll('=', ''),
        },
      }),
    );
    await queryRequest.response.close();

    expect(await requests.moveNext(), isTrue);
    final consumeRequest = requests.current;
    expect(consumeRequest.uri.path, '/api/auth/device-pairing/consume');
    final firstConsumeBody = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(consumeRequest).join()),
    );
    final finalSessionToken = _requiredTestString(
      firstConsumeBody,
      'sessionToken',
    );
    expect(
      CloudSyncFullSessionToken.parse(finalSessionToken).value,
      isNotEmpty,
    );
    expect(
      await store.readPendingPairingEnvelope(
        normalizedBaseUrl: serviceBaseUrl,
        normalizedLoginName: loginName,
      ),
      isNotNull,
    );
    final persistedKey = await core.openSlot(
      _authenticatorSlotId(serviceBaseUrl, loginName),
    );
    final persistedState = await core.openDeviceState(
      persistedKey,
      stateBlob: (await store.read(
        normalizedBaseUrl: serviceBaseUrl,
        normalizedLoginName: loginName,
      ))!,
    );
    expect(persistedState.binding.account?.keyEpoch, 1);
    expect(
      persistedState.binding.account?.userId,
      orderedEquals(_rawUuid(_userId)),
    );
    await core.closeAccountRootKey(persistedState.ark!);
    await core.closeDeviceIdentity(persistedState.identity);
    await core.close(persistedKey);

    final consumeSocket = await consumeRequest.response.detachSocket();
    consumeSocket.destroy();
    await expectLater(completionFuture, throwsA(isA<CloudSyncException>()));
    client.close(force: true);

    final recoveryClient = CloudSyncClient.forTesting(
      baseUrl: transportBaseUrl,
    );
    final recoveryAuthenticator = E2eeAccountAuthenticator(
      baseUrl: serviceBaseUrl,
      accountClient: recoveryClient,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() => recoveryClient.close(force: true));
    final password = Uint8List.fromList(utf8.encode('password'));
    final recoveryFuture = recoveryAuthenticator.loginDevice(
      loginName: loginName,
      password: password,
      deviceName: 'Windows 主机',
      platform: CloudSyncPlatform.windows,
      clientVersion: '1.2.3',
    );
    expect(await requests.moveNext(), isTrue);
    final retriedConsumeRequest = requests.current;
    expect(retriedConsumeRequest.uri.path, '/api/auth/device-pairing/consume');
    expect(
      copyCloudSyncJsonMap(
        jsonDecode(await utf8.decoder.bind(retriedConsumeRequest).join()),
      ),
      firstConsumeBody,
    );
    retriedConsumeRequest.response.headers.contentType = ContentType.json;
    retriedConsumeRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': _pairingAuthenticatedData(
          token: finalSessionToken,
          keyEpoch: 1,
          deviceId: _deviceId2,
          loginName: loginName,
          pairingId: pairingId,
          membershipManifest: pairedMembership.manifest,
          recoveryPublicKey: recoveryPublicKey,
          recoveryCapsule: recoveryCapsule,
          accountKeyEnvelope: approvalBundle.envelope,
        ),
      }),
    );
    await retriedConsumeRequest.response.close();
    final recoveryResult = await recoveryFuture;
    expect(recoveryResult, isA<E2eeAccountLoginAuthenticated>());
    final session = (recoveryResult as E2eeAccountLoginAuthenticated).session;
    expect(session.user.id, _userId);
    expect(session.device.id, _deviceId2);
    expect(session.deviceKeyVersion, 1);
    expect(password, everyElement(0));
    expect(
      await store.readPendingPairingEnvelope(
        normalizedBaseUrl: serviceBaseUrl,
        normalizedLoginName: loginName,
      ),
      isNotNull,
    );

    final originalPendingEnvelope = (await store.readPendingPairingEnvelope(
      normalizedBaseUrl: serviceBaseUrl,
      normalizedLoginName: loginName,
    ))!;
    final recoveryKey = await core.openSlot(
      _authenticatorSlotId(serviceBaseUrl, loginName),
    );
    final recoveryRecordId = _pairingRecoveryRecordId(
      serviceBaseUrl,
      loginName,
    );
    final recoveryAssociatedData = _pairingRecoveryAssociatedData(
      serviceBaseUrl,
      loginName,
    );
    Uint8List? recoveryFrame;
    try {
      recoveryFrame = await core.openRecord(
        recoveryKey,
        recordId: recoveryRecordId,
        epoch: 1,
        associatedData: recoveryAssociatedData,
        envelope: originalPendingEnvelope,
      );
      for (final corruption in <String>['version', 'reserved', 'length']) {
        final corruptedFrame = Uint8List.fromList(recoveryFrame);
        final corruptedPayload = switch (corruption) {
          'version' =>
            corruptedFrame
              ..[8] = 0
              ..[9] = 2,
          'reserved' => corruptedFrame..[10] = 1,
          'length' => Uint8List.fromList(
            corruptedFrame.sublist(0, corruptedFrame.length - 1),
          ),
          _ => throw StateError('未知恢复帧破坏类型'),
        };
        final corruptedEnvelope = await core.sealRecord(
          recoveryKey,
          recordId: recoveryRecordId,
          epoch: 1,
          associatedData: recoveryAssociatedData,
          plaintext: corruptedPayload,
        );
        try {
          final removedOriginal = await store.deletePendingPairingEnvelope(
            normalizedBaseUrl: serviceBaseUrl,
            normalizedLoginName: loginName,
            expectedDigest: Uint8List.fromList(
              sha256.convert(originalPendingEnvelope).bytes,
            ),
          );
          expect(removedOriginal, isTrue, reason: corruption);
          await store.writePendingPairingEnvelope(
            normalizedBaseUrl: serviceBaseUrl,
            normalizedLoginName: loginName,
            envelope: corruptedEnvelope,
          );
          await expectLater(
            recoveryAuthenticator.confirmDevicePairing(
              loginName: loginName,
              session: session,
            ),
            throwsFormatException,
            reason: corruption,
          );
        } finally {
          corruptedFrame.fillRange(0, corruptedFrame.length, 0);
          corruptedPayload.fillRange(0, corruptedPayload.length, 0);
          await store.deletePendingPairingEnvelope(
            normalizedBaseUrl: serviceBaseUrl,
            normalizedLoginName: loginName,
            expectedDigest: Uint8List.fromList(
              sha256.convert(corruptedEnvelope).bytes,
            ),
          );
          corruptedEnvelope.fillRange(0, corruptedEnvelope.length, 0);
          await store.writePendingPairingEnvelope(
            normalizedBaseUrl: serviceBaseUrl,
            normalizedLoginName: loginName,
            envelope: originalPendingEnvelope,
          );
        }
      }
    } finally {
      recoveryFrame?.fillRange(0, recoveryFrame.length, 0);
      recoveryRecordId.fillRange(0, recoveryRecordId.length, 0);
      recoveryAssociatedData.fillRange(0, recoveryAssociatedData.length, 0);
      await core.close(recoveryKey);
    }

    final state = session.securityState!;
    final receipt = session.pairingReceipt!;
    final alternateIssuerState = _copySecurityState(
      state,
      membershipManifest: alternateIssuerMembership.manifest,
    );
    await expectLater(
      recoveryAuthenticator.confirmDevicePairing(
        loginName: loginName,
        session: _copyAuthenticatedSession(
          session,
          securityState: alternateIssuerState,
          pairingReceipt: CloudSyncDevicePairingConsumptionReceipt(
            pairingId: receipt.pairingId,
            issuerDeviceId: receipt.issuerDeviceId,
            keyEpoch: receipt.keyEpoch,
            securityGeneration: receipt.securityGeneration,
            membershipManifestDigest:
                alternateIssuerState.membershipManifestDigest,
          ),
        ),
      ),
      throwsStateError,
      reason: '签发者双公钥被替换',
    );
    await expectLater(
      recoveryAuthenticator.confirmDevicePairing(
        loginName: loginName,
        session: _copyAuthenticatedSession(session, authGeneration: 2),
      ),
      throwsStateError,
      reason: '目标设备认证代次不连续',
    );
    await expectLater(
      recoveryAuthenticator.confirmDevicePairing(
        loginName: loginName,
        session: _copyAuthenticatedSession(
          session,
          pairingReceipt: CloudSyncDevicePairingConsumptionReceipt(
            pairingId: receipt.pairingId,
            issuerDeviceId: _deviceId1,
            keyEpoch: receipt.keyEpoch,
            securityGeneration: receipt.securityGeneration,
            membershipManifestDigest: receipt.membershipManifestDigest,
          ),
        ),
      ),
      throwsStateError,
      reason: '消费回执签发者不一致',
    );
    final envelope = state.envelopes.single;
    final mismatchedEnvelopeState = _copySecurityState(
      state,
      envelopes: <CloudSyncAccountSecurityEnvelope>[
        CloudSyncAccountSecurityEnvelope(
          targetDeviceId: envelope.targetDeviceId,
          issuerDeviceId: envelope.issuerDeviceId,
          envelopeVersion: envelope.envelopeVersion,
          keyEpoch: envelope.keyEpoch,
          accountKeyEnvelope: _filledBytes(
            cloudSyncAccountKeyEnvelopeBytes,
            0x7a,
          ),
        ),
      ],
    );
    await expectLater(
      recoveryAuthenticator.confirmDevicePairing(
        loginName: loginName,
        session: _copyAuthenticatedSession(
          session,
          securityState: mismatchedEnvelopeState,
        ),
      ),
      throwsStateError,
      reason: '冻结批准信封不一致',
    );
    expect(
      () => _copyAuthenticatedSession(
        session,
        pairingReceipt: CloudSyncDevicePairingConsumptionReceipt(
          pairingId: receipt.pairingId,
          issuerDeviceId: receipt.issuerDeviceId,
          keyEpoch: receipt.keyEpoch,
          securityGeneration: receipt.securityGeneration,
          membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
            _filledBytes(cloudSyncMembershipManifestDigestBytes, 0x7b),
          ),
        ),
      ),
      throwsFormatException,
      reason: '消费回执摘要与安全状态不一致',
    );
    expect(
      await store.readPendingPairingEnvelope(
        normalizedBaseUrl: serviceBaseUrl,
        normalizedLoginName: loginName,
      ),
      isNotNull,
    );
    await recoveryAuthenticator.confirmDevicePairing(
      loginName: loginName,
      session: session,
    );
    expect(
      await store.readPendingPairingEnvelope(
        normalizedBaseUrl: serviceBaseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );
    originalPendingEnvelope.fillRange(0, originalPendingEnvelope.length, 0);
  });

  test('设备配对全生命周期按令牌能力隔离并显式接管完整会话', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <(String, String?, CloudSyncJsonMap)>[];
    var queryCount = 0;
    final subscription = server.listen((request) async {
      final body = copyCloudSyncJsonMap(
        jsonDecode(await utf8.decoder.bind(request).join()),
      );
      requests.add((
        request.uri.path,
        request.headers.value(HttpHeaders.authorizationHeader),
        body,
      ));
      final Object data = switch (request.uri.path) {
        '/api/auth/device-pairing/create' => <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': _pairingId,
          'accountContextId': _accountContextId,
          'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
          'expiresAt': '2026-07-26T05:05:00.000Z',
          'targetDevice': _pairingTargetJson(),
        },
        '/api/auth/device-pairing/query' => <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': _pairingId,
          'accountContextId': _accountContextId,
          'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
          'expiresAt': '2026-07-26T05:05:00.000Z',
          'targetDevice': _pairingTargetJson(),
          'status': ++queryCount == 1 ? 'pending' : 'approved',
          if (queryCount > 1) ...<String, Object?>{
            'issuerDeviceId': _issuerDeviceId,
            'issuerKeyVersion': 1,
            'issuerAuthGeneration': 0,
            'issuerSigningPublicKey': _encodedBytes(
              cloudSyncDevicePublicKeyBytes,
              19,
            ),
            'issuerKeyAgreementPublicKey': _encodedBytes(
              cloudSyncDevicePublicKeyBytes,
              20,
            ),
            'keyEpoch': 23,
            'accountKeyEnvelope': _encodedBytes(
              cloudSyncAccountKeyEnvelopeBytes,
              21,
            ),
            'deviceProof': _encodedBytes(cloudSyncDeviceProofBytes, 22),
            'pairingAuthenticator': _encodedBytes(
              cloudSyncPairingAuthenticatorBytes,
              23,
            ),
          },
        },
        '/api/auth/device-pairing/approve' => <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': _pairingId,
          'result': 'approved',
          'approvedAt': '2026-07-26T05:01:00.000Z',
        },
        '/api/auth/device-pairing/consume' => _pairingAuthenticatedData(
          token: _requiredTestString(body, 'sessionToken'),
          keyEpoch: 23,
          deviceId: _deviceId2,
        ),
        '/api/auth/device-pairing/cancel' => <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': _pairingId,
          'result': 'cancelled',
          'cancelledAt': '2026-07-26T05:02:00.000Z',
        },
        '/api/device/trusted/list' => <String, Object?>{
          'items': <Object?>[_trustedDeviceJson()],
          'total': 1,
          'pageIndex': 1,
          'pageSize': 10,
        },
        '/api/device/trusted/revoke' => <String, Object?>{
          'device': _trustedDeviceJson(status: 'revoked'),
        },
        _ => throw StateError('未预期的请求路径：${request.uri.path}'),
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'data': data}));
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final created = await client.createDevicePairing(
      token: _onboardingToken,
      pairingId: _pairingId,
      pairingSecretHash: _filledBytes(cloudSyncPairingSecretHashBytes, 24),
    );
    final pending = await client.queryDevicePairing(
      token: _onboardingToken,
      pairingId: _pairingId,
    );
    final approved = await client.queryDevicePairing(
      token: _onboardingToken,
      pairingId: _pairingId,
    );
    final finalSessionToken = CloudSyncFullSessionToken.generate();
    final session = await client.consumeDevicePairing(
      token: _onboardingToken,
      pairingId: _pairingId,
      sessionToken: finalSessionToken,
    );
    await expectLater(
      client.listDevices(),
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.unauthenticated,
        ),
      ),
    );
    client.setToken(session.token);
    final devices = await client.listDevices(
      status: CloudSyncDeviceStatus.active,
      pageSize: 10,
    );
    await expectLater(
      client.revokeDevice(_deviceId2),
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.serverCode,
          'serverCode',
          'SYNC_DEVICE_ROTATION_REQUIRED',
        ),
      ),
    );
    final cancellation = await client.cancelDevicePairing(
      token: _onboardingToken,
      pairingId: _pairingId,
    );

    expect(created.targetDevice.id, _deviceId2);
    expect(created.challenge, everyElement(18));
    expect(pending, isA<CloudSyncDevicePairingPending>());
    expect(
      approved,
      isA<CloudSyncDevicePairingApproved>()
          .having((result) => result.keyEpoch, 'keyEpoch', 23)
          .having(
            (result) => result.issuerDeviceId,
            'issuerDeviceId',
            _issuerDeviceId,
          )
          .having(
            (result) => result.accountKeyEnvelope,
            'accountKeyEnvelope',
            everyElement(21),
          ),
    );
    expect(session.keyEpoch, 23);
    expect(session.device.id, _deviceId2);
    expect(session.token.value, finalSessionToken.value);
    expect(devices.items.single.id, _deviceId2);
    expect(cancellation.pairingId, _pairingId);

    final onboardingHeader = 'Bearer $_onboardingTokenValue';
    final pairedSessionHeader = 'Bearer ${finalSessionToken.value}';
    for (final request in requests) {
      final expectedHeader = switch (request.$1) {
        '/api/device/trusted/list' => pairedSessionHeader,
        _ => onboardingHeader,
      };
      expect(request.$2, expectedHeader, reason: request.$1);
    }
    expect(requests.first.$3, <String, Object?>{
      'protocolVersion': cloudSyncOpaqueProtocolVersion,
      'pairingId': _pairingId,
      'pairingSecretHash': _encodedBytes(cloudSyncPairingSecretHashBytes, 24),
    });
    expect(requests[3].$3['sessionToken'], finalSessionToken.value);
    expect(requests[4].$3, <String, Object?>{
      'status': 'active',
      'pageIndex': 1,
      'pageSize': 10,
    });
    expect(
      requests.any(
        (request) => request.$1 == '/api/auth/device-pairing/approve',
      ),
      isFalse,
    );
  });

  test('设备配对消费拒绝服务端替换客户端会话令牌', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late final CloudSyncJsonMap requestBody;
    final subscription = server.listen((request) async {
      requestBody = copyCloudSyncJsonMap(
        jsonDecode(await utf8.decoder.bind(request).join()),
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': _pairingAuthenticatedData(
            token: _otherFullTokenValue,
            deviceId: _deviceId2,
          ),
        }),
      );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final expectedToken = CloudSyncFullSessionToken.generate();

    await expectLater(
      client.consumeDevicePairing(
        token: _onboardingToken,
        pairingId: _pairingId,
        sessionToken: expectedToken,
      ),
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.invalidResponse,
        ),
      ),
    );
    expect(requestBody['sessionToken'], expectedToken.value);
  });

  test('设备配对 QR 完整 transcript 规范编码并转移敏感缓冲区所有权', () {
    final now = DateTime.utc(2026, 7, 26, 5);
    final sourceSecret = _filledBytes(cloudSyncPairingSecretBytes, 24);
    final payload = CloudSyncDevicePairingQrPayload.fromCreatedPairing(
      created: _pairingQrCreated(),
      normalizedServiceOrigin: defaultCloudSyncBaseUrl,
      pairingSecret: sourceSecret,
      now: now,
    );
    final frame = CloudSyncDevicePairingQrCodec.encode(payload, now: now);
    final serviceOriginBytes = ascii.encode(defaultCloudSyncBaseUrl);
    final deviceNameBytes = utf8.encode('Android 手机');
    final clientVersionBytes = ascii.encode('1.2.3');
    final expectedLength =
        cloudSyncPairingQrMinimumFrameBytes +
        serviceOriginBytes.length +
        deviceNameBytes.length +
        clientVersionBytes.length;
    final frameData = ByteData.sublistView(frame);

    expect(frame, hasLength(expectedLength));
    expect(frame.sublist(0, 20), <int>[
      0x4b,
      0x4c,
      0x50,
      0x51,
      cloudSyncPairingQrFrameVersion,
      0,
      expectedLength >> 8,
      expectedLength & 0xff,
      0,
      0,
      0,
      cloudSyncOpaqueProtocolVersion,
      1,
      deviceNameBytes.length,
      clientVersionBytes.length,
      serviceOriginBytes.length,
      0,
      0,
      0,
      0,
    ]);
    expect(frameData.getUint32(20, Endian.big), 1);
    expect(
      frameData.getUint64(24, Endian.big),
      DateTime.utc(2026, 7, 26, 5, 5).millisecondsSinceEpoch,
    );
    expect(frame.sublist(80, 112), everyElement(18));
    expect(frame.sublist(112, 144), everyElement(4));
    expect(frame.sublist(144, 176), everyElement(5));
    expect(frame.sublist(176, 208), everyElement(24));
    expect(
      frame.sublist(208, 208 + serviceOriginBytes.length),
      serviceOriginBytes,
    );
    final deviceNameOffset = 208 + serviceOriginBytes.length;
    expect(
      frame.sublist(
        deviceNameOffset,
        deviceNameOffset + deviceNameBytes.length,
      ),
      deviceNameBytes,
    );
    expect(
      frame.sublist(
        deviceNameOffset + deviceNameBytes.length,
        frame.length - 4,
      ),
      clientVersionBytes,
    );
    expect(
      frameData.getUint32(frame.length - 4, Endian.big),
      getCrc32(Uint8List.sublistView(frame, 0, frame.length - 4)),
    );

    payload.dispose();
    expect(sourceSecret, everyElement(0));
    final decoded = CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
      frame,
      now: now,
    );
    expect(frame, everyElement(0));
    expect(decoded.protocolVersion, cloudSyncOpaqueProtocolVersion);
    expect(decoded.normalizedServiceOrigin, defaultCloudSyncBaseUrl);
    expect(
      () => decoded.requireServiceOriginMatches('https://other.example'),
      throwsFormatException,
    );
    expect(
      () => decoded.requireServiceOriginMatches(defaultCloudSyncBaseUrl),
      returnsNormally,
    );
    expect(decoded.platform, CloudSyncPlatform.android);
    expect(decoded.untrustedDeviceName, 'Android 手机');
    expect(decoded.untrustedClientVersion, '1.2.3');
    expect(decoded.keyVersion, 1);
    expect(decoded.expiresAt, DateTime.utc(2026, 7, 26, 5, 5));
    expect(decoded.pairingId, _pairingId);
    expect(decoded.accountContextId, _userId);
    expect(decoded.targetDeviceId, _deviceId2);
    expect(decoded.challenge, everyElement(18));
    expect(decoded.signingPublicKey, everyElement(4));
    expect(decoded.keyAgreementPublicKey, everyElement(5));
    expect(
      () => decoded.requireAccountContextMatchesLocalUserId(_userId),
      returnsNormally,
    );
    expect(
      () => decoded.requireAccountContextMatchesLocalUserId(_accountContextId),
      throwsA(isA<FormatException>()),
    );
    final decodedSecret = decoded.takePairingSecret();
    expect(decodedSecret, everyElement(24));
    expect(decoded.isDisposed, isTrue);
    decodedSecret.fillRange(0, decodedSecret.length, 0);
    expect(decodedSecret, everyElement(0));

    final disposableFrame = _validPairingQrFrame();
    final disposableDecoded =
        CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          disposableFrame,
          now: now,
        );
    disposableDecoded.dispose();
    expect(disposableDecoded.isDisposed, isTrue);
    expect(disposableDecoded.takePairingSecret, throwsStateError);
  });

  final invalidPairingQrPayloads =
      <
        ({
          String name,
          CloudSyncDevicePairingQrPayload Function(Uint8List secret) create,
        })
      >[
        (
          name: '协议版本',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            protocolVersion: cloudSyncOpaqueProtocolVersion + 1,
          ),
        ),
        (
          name: '服务 origin 非 HTTPS',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            normalizedServiceOrigin: 'http://localhost',
          ),
        ),
        (
          name: '服务 origin 尾斜杠',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            normalizedServiceOrigin: '$defaultCloudSyncBaseUrl/',
          ),
        ),
        (
          name: '服务 origin 规范化差异',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            normalizedServiceOrigin: 'https://KELIVO.bemylover.top',
          ),
        ),
        (
          name: '设备名空白',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            deviceName: ' Android 手机',
          ),
        ),
        (
          name: '设备名长度',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            deviceName: List<String>.filled(81, 'x').join(),
          ),
        ),
        (
          name: '客户端版本',
          create: (secret) =>
              _pairingQrPayload(pairingSecret: secret, clientVersion: '1/2'),
        ),
        (
          name: 'keyVersion 下界',
          create: (secret) =>
              _pairingQrPayload(pairingSecret: secret, keyVersion: 0),
        ),
        (
          name: 'keyVersion 上界',
          create: (secret) =>
              _pairingQrPayload(pairingSecret: secret, keyVersion: 0x80000000),
        ),
        (
          name: 'pairingId 规范形式',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            pairingId: 'ABCDEFAB-CDEF-4ABC-8DEF-ABCDEFABCDEF',
          ),
        ),
        (
          name: 'accountContextId UUID 版本',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            accountContextId: 'abcdefab-cdef-3abc-8def-abcdefabcdef',
          ),
        ),
        (
          name: 'targetDeviceId UUID variant',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            targetDeviceId: 'abcdefab-cdef-4abc-7def-abcdefabcdef',
          ),
        ),
        (
          name: 'challenge 长度',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            challenge: _filledBytes(cloudSyncDeviceChallengeBytes - 1),
          ),
        ),
        (
          name: '签名公钥长度',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            signingPublicKey: _filledBytes(cloudSyncDevicePublicKeyBytes + 1),
          ),
        ),
        (
          name: '密钥协商公钥长度',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            keyAgreementPublicKey: _filledBytes(
              cloudSyncDevicePublicKeyBytes - 1,
            ),
          ),
        ),
        (
          name: '到期边界',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            expiresAt: DateTime.utc(2026, 7, 26, 5),
          ),
        ),
        (
          name: '五分钟上界',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            expiresAt: DateTime.utc(2026, 7, 26, 5, 5, 0, 1),
          ),
        ),
        (
          name: '毫秒精度',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            expiresAt: DateTime.utc(
              2026,
              7,
              26,
              5,
              4,
            ).add(const Duration(microseconds: 1)),
          ),
        ),
      ];
  for (final invalid in invalidPairingQrPayloads) {
    test('设备配对 QR payload 拒绝非法${invalid.name}并清零 secret', () {
      final secret = _filledBytes(cloudSyncPairingSecretBytes, 24);

      expect(() => invalid.create(secret), throwsA(isA<FormatException>()));
      expect(secret, everyElement(0));
    });
  }

  test('设备配对 QR payload 拒绝错误 secret 长度并清零', () {
    final secret = _filledBytes(cloudSyncPairingSecretBytes - 1, 24);

    expect(
      () => _pairingQrPayload(pairingSecret: secret),
      throwsA(isA<FormatException>()),
    );
    expect(secret, everyElement(0));
  });

  final invalidPairingQrFrames =
      <({String name, void Function(Uint8List frame) mutate})>[
        (name: 'magic', mutate: (frame) => frame[0] ^= 0xff),
        (name: 'v1 帧版本', mutate: (frame) => frame[4] = 1),
        (name: '未知 flags', mutate: (frame) => frame[5] = 1),
        (
          name: 'totalLength',
          mutate: (frame) => ByteData.sublistView(
            frame,
          ).setUint16(6, frame.length - 1, Endian.big),
        ),
        (name: '设备名长度', mutate: (frame) => frame[13] += 1),
        (name: '服务 origin 长度', mutate: (frame) => frame[15] += 1),
        (name: '未知保留字段', mutate: (frame) => frame[16] = 1),
        (name: 'CRC', mutate: (frame) => frame[176] ^= 0xff),
      ];
  for (final invalid in invalidPairingQrFrames) {
    test('设备配对 QR 解码拒绝非法${invalid.name}并清零帧', () {
      final frame = _validPairingQrFrame();
      invalid.mutate(frame);

      expect(
        () => CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          frame,
          now: DateTime.utc(2026, 7, 26, 5),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(frame, everyElement(0));
    });
  }

  final invalidPairingQrTranscripts =
      <({String name, void Function(Uint8List frame) mutate})>[
        (
          name: 'protocolVersion',
          mutate: (frame) {
            ByteData.sublistView(frame).setUint32(8, 2, Endian.big);
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'platform',
          mutate: (frame) {
            frame[12] = 0;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'keyVersion',
          mutate: (frame) {
            ByteData.sublistView(frame).setUint32(20, 0, Endian.big);
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'expiresAt',
          mutate: (frame) {
            ByteData.sublistView(
              frame,
            ).setUint64(24, 0xffffffffffffffff, Endian.big);
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'pairingId UUID',
          mutate: (frame) {
            frame[32 + 6] = (frame[32 + 6] & 0x0f) | 0x30;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'accountContextId UUID',
          mutate: (frame) {
            frame[48 + 8] = (frame[48 + 8] & 0x3f) | 0x40;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'targetDeviceId UUID',
          mutate: (frame) {
            frame[64 + 6] = (frame[64 + 6] & 0x0f) | 0x50;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: '服务 origin 规范化差异',
          mutate: (frame) {
            frame[208 + 'https://'.length] = 0x4b;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: '设备名 UTF-8',
          mutate: (frame) {
            frame[208 + frame[15]] = 0xff;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'clientVersion',
          mutate: (frame) {
            final clientVersionOffset = 208 + frame[15] + frame[13];
            frame[clientVersionOffset] = 0x2f;
            _refreshPairingQrCrc(frame);
          },
        ),
      ];
  for (final invalid in invalidPairingQrTranscripts) {
    test('设备配对 QR 解码拒绝非法${invalid.name}并清零帧', () {
      final frame = _validPairingQrFrame();
      invalid.mutate(frame);

      expect(
        () => CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          frame,
          now: DateTime.utc(2026, 7, 26, 5),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(frame, everyElement(0));
    });
  }

  for (final invalidOrigin in <String>[
    'http://kelivo.bemylover.top',
    '$defaultCloudSyncBaseUrl/',
    'https://KELIVO.bemylover.top',
  ]) {
    test('设备配对 QR 解码拒绝非规范服务 origin $invalidOrigin 并清零帧', () {
      final frame = _replacePairingQrServiceOrigin(
        _validPairingQrFrame(),
        invalidOrigin,
      );

      expect(
        () => CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          frame,
          now: DateTime.utc(2026, 7, 26, 5),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(frame, everyElement(0));
    });
  }

  for (final lengthDelta in <int>[-1, 1]) {
    test('设备配对 QR 解码拒绝非规范总长度 $lengthDelta', () {
      final validFrame = _validPairingQrFrame();
      final frame = Uint8List(validFrame.length + lengthDelta);
      frame.setRange(
        0,
        lengthDelta < 0 ? frame.length : validFrame.length,
        validFrame,
      );
      validFrame.fillRange(0, validFrame.length, 0);

      expect(
        () => CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          frame,
          now: DateTime.utc(2026, 7, 26, 5),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(frame, everyElement(0));
    });
  }

  for (final decodeNow in <DateTime>[
    DateTime.utc(2026, 7, 26, 4, 59, 59, 999),
    DateTime.utc(2026, 7, 26, 5, 5),
  ]) {
    test('设备配对 QR 解码拒绝越界时间 $decodeNow 并清零帧', () {
      final frame = _validPairingQrFrame();

      expect(
        () => CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          frame,
          now: decodeNow,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(frame, everyElement(0));
    });
  }

  test('认证与配对请求在发网前拒绝错误长度和越界 keyEpoch', () {
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    addTearDown(() => client.close(force: true));
    final identity = _deviceIdentity();
    final invalidCalls = <(String, Object? Function())>[
      (
        '注册请求长度',
        () => client.startOpaqueRegistration(
          loginName: 'alice',
          displayName: 'Alice',
          device: identity,
          registrationRequest: _filledBytes(
            cloudSyncOpaqueRegistrationRequestBytes - 1,
          ),
        ),
      ),
      (
        '注册上传长度',
        () => client.finishOpaqueRegistration(
          attemptId: _attemptId1,
          registrationUpload: _filledBytes(
            cloudSyncOpaqueRegistrationUploadBytes + 1,
          ),
          accountKeyEnvelope: _filledBytes(cloudSyncAccountKeyEnvelopeBytes),
          securityState: _genesisSecurityState(),
          deviceProof: _filledBytes(cloudSyncDeviceProofBytes),
        ),
      ),
      (
        '登录请求长度',
        () => client.startOpaqueLogin(
          loginName: 'alice',
          device: identity,
          credentialRequest: _filledBytes(
            cloudSyncOpaqueCredentialRequestBytes - 1,
          ),
        ),
      ),
      (
        '登录完成长度',
        () => client.finishOpaqueLogin(
          attemptId: _attemptId1,
          credentialFinalization: _filledBytes(
            cloudSyncOpaqueCredentialFinalizationBytes - 1,
          ),
          deviceProof: _filledBytes(cloudSyncDeviceProofBytes),
        ),
      ),
      (
        '配对密钥摘要长度',
        () => client.createDevicePairing(
          token: _onboardingToken,
          pairingId: _pairingId,
          pairingSecretHash: _filledBytes(cloudSyncPairingSecretHashBytes + 1),
        ),
      ),
    ];

    for (final invalidCall in invalidCalls) {
      expect(
        invalidCall.$2,
        throwsA(
          isA<CloudSyncException>()
              .having(
                (error) => error.kind,
                'kind',
                CloudSyncFailureKind.validation,
              )
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
        reason: invalidCall.$1,
      );
    }
  });

  test('认证响应拒绝非规范 Base64URL 和 generated 模型缺字段', () async {
    final canonicalChallenge = _encodedBytes(cloudSyncDeviceChallengeBytes);
    final invalidChallenges = <String>[
      '$canonicalChallenge=',
      '${canonicalChallenge.substring(0, canonicalChallenge.length - 1)}B',
      canonicalChallenge.substring(0, canonicalChallenge.length - 1),
    ];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestIndex = 0;
    final subscription = server.listen((request) async {
      await utf8.decoder.bind(request).join();
      final currentIndex = requestIndex++;
      final omitRegistrationResponse = currentIndex == invalidChallenges.length;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'protocolVersion': cloudSyncOpaqueProtocolVersion,
            'attemptId': _attemptId1,
            'userId': _userId,
            'accountBinding': _accountContextId,
            'deviceChallenge': omitRegistrationResponse
                ? canonicalChallenge
                : invalidChallenges[currentIndex],
            if (!omitRegistrationResponse)
              'registrationResponse': _encodedBytes(
                cloudSyncOpaqueRegistrationResponseBytes,
              ),
            'expiresAt': '2026-07-26T05:05:00.000Z',
          },
        }),
      );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final invalidResponse = throwsA(
      isA<CloudSyncException>()
          .having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.invalidResponse,
          )
          .having((error) => error.retryable, 'retryable', isFalse),
    );
    for (var index = 0; index <= invalidChallenges.length; index++) {
      await expectLater(
        client.startOpaqueRegistration(
          loginName: 'alice',
          displayName: 'Alice',
          device: _deviceIdentity(),
          registrationRequest: _filledBytes(
            cloudSyncOpaqueRegistrationRequestBytes,
          ),
        ),
        invalidResponse,
      );
    }
  });

  test('同步服务响应重定向时拒绝访问目标地址', () async {
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var targetRequestCount = 0;
    final targetSubscription = target.listen((request) async {
      targetRequestCount++;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'service': 'kelivo-api',
            'status': 'ok',
            'timestamp': '2026-07-19T05:00:00.000Z',
          },
        }),
      );
      await request.response.close();
    });

    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final originSubscription = origin.listen((request) async {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(
          HttpHeaders.locationHeader,
          'http://${target.address.address}:${target.port}'
          '/api/system/health/get',
        );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${origin.address.address}:${origin.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await originSubscription.cancel();
      await targetSubscription.cancel();
      await origin.close(force: true);
      await target.close(force: true);
    });

    await expectLater(
      client.health(),
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having(
              (error) => error.statusCode,
              'statusCode',
              HttpStatus.found,
            ),
      ),
    );
    expect(targetRequestCount, 0);
  });

  test('账户记录加密器派生稳定不透明标识并限制明文生命周期', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 7,
    );
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    addTearDown(cipher.close);

    const entityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-1',
    );
    const otherEntityKey = SyncEntityKey(
      entityType: 'message',
      entityId: 'conversation-1',
    );
    final payload = Uint8List.fromList(<int>[1, 2, 3]);
    final firstId = await cipher.deriveRecordId(entityKey);
    final repeatedId = await cipher.deriveRecordId(entityKey);
    final otherId = await cipher.deriveRecordId(otherEntityKey);
    final first = await cipher.seal(entityKey: entityKey, payload: payload);
    final second = await cipher.seal(entityKey: entityKey, payload: payload);

    expect(firstId, repeatedId);
    expect(first.recordId, firstId);
    expect(otherId, isNot(firstId));
    expect(first.ciphertext, isNot(orderedEquals(second.ciphertext)));
    final recordIdBytes = _rawUuid(firstId.wireValue);
    expect(recordIdBytes[6] & 0xf0, 0x40);
    expect(recordIdBytes[8] & 0xc0, 0x80);
    expect(payload, orderedEquals(<int>[1, 2, 3]));

    Uint8List? borrowedPayload;
    final opened = await cipher.open(
      _untrustedRecord(first),
      decode: (openedKey, borrowed) {
        expect(openedKey, entityKey);
        borrowedPayload = borrowed;
        return Uint8List.fromList(borrowed);
      },
    );
    expect(opened, orderedEquals(payload));
    expect(borrowedPayload, everyElement(0));
    expect(payload, orderedEquals(<int>[1, 2, 3]));
  });

  test('账户记录重包只接受相邻密钥世代并保持认证内容', () async {
    const core = KelivoSecureCore();
    final userId = _rawUuid(_userId);
    final issuerIdentity = await core.generateDeviceIdentity();
    final targetIdentity = await core.generateDeviceIdentity();
    addTearDown(() => core.closeDeviceIdentity(issuerIdentity));
    addTearDown(() => core.closeDeviceIdentity(targetIdentity));
    final issuerPublicKeys = await core.readDevicePublicKeys(issuerIdentity);
    final targetPublicKeys = await core.readDevicePublicKeys(targetIdentity);

    final sourceArk = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 1,
    );
    final epochOneEnvelope = await core.sealAccountRootKeyEnvelope(
      issuerIdentity,
      sourceArk,
      userId: userId,
      issuerDeviceId: _rawUuid(_deviceId1),
      targetDeviceId: _rawUuid(_deviceId2),
      keyEpoch: 1,
      targetPublicKeys: targetPublicKeys,
    );
    final targetArk = await core.openAccountRootKeyEnvelope(
      targetIdentity,
      envelope: epochOneEnvelope,
      userId: userId,
      issuerDeviceId: _rawUuid(_deviceId1),
      targetDeviceId: _rawUuid(_deviceId2),
      keyEpoch: 1,
      issuerPublicKeys: issuerPublicKeys,
      targetPublicKeys: targetPublicKeys,
    );
    final epochTwoArk = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 2,
    );
    addTearDown(() => core.closeAccountRootKey(epochTwoArk));
    await core.addAccountRootKeyEpoch(targetArk, source: epochTwoArk);

    final sourceCipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: sourceArk,
      userId: _userId,
      currentKeyEpoch: 1,
    );
    final targetCipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: targetArk,
      userId: _userId,
      currentKeyEpoch: 2,
    );
    addTearDown(sourceCipher.close);
    addTearDown(targetCipher.close);

    const entityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'data-rekey-record',
    );
    final payload = Uint8List.fromList(<int>[4, 8, 15, 16, 23, 42]);
    final source = await sourceCipher.seal(
      entityKey: entityKey,
      payload: payload,
    );

    final target = await targetCipher.rewrap(_untrustedRecord(source));

    expect(target.keyEpoch, 2);
    expect(target.recordId, isNot(source.recordId));
    expect(target.ciphertext, isNot(orderedEquals(source.ciphertext)));
    expect(
      await targetCipher.open(
        _untrustedRecord(target),
        decode: (openedKey, borrowed) {
          expect(openedKey, entityKey);
          return Uint8List.fromList(borrowed);
        },
      ),
      orderedEquals(payload),
    );
    await expectLater(
      targetCipher.rewrap(_untrustedRecord(target)),
      throwsFormatException,
    );

    final nonCanonicalSource = await _sealRawAccountRecord(
      core: core,
      ark: sourceArk,
      recordIdKey: entityKey,
      frameKey: const SyncEntityKey(
        entityType: 'conversation',
        entityId: '\ufeffdata-rekey-record',
      ),
      userId: _userId,
      keyEpoch: 1,
    );
    await expectLater(
      targetCipher.rewrap(nonCanonicalSource),
      throwsFormatException,
    );
  });

  test('账户记录加密器按记录代次派生标识并在裁剪后失败关闭', () async {
    const core = KelivoSecureCore();
    final slotId = Uint8List.fromList(
      sha256
          .convert(utf8.encode('e2ee-record-epoch-derivation'))
          .bytes
          .sublist(0, 16),
    );
    late final KelivoKeyHandle key;
    try {
      key = await core.createSlot(slotId);
    } on KelivoSecureCoreException catch (error) {
      if (error.status != KelivoSecureCoreStatus.slotAlreadyExists) rethrow;
      key = await core.openSlot(slotId);
    }
    addTearDown(() => core.close(key));

    final userId = _rawUuid(_userId);
    final identity = await core.generateDeviceIdentity();
    addTearDown(() => core.closeDeviceIdentity(identity));
    final initialArk = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 1,
    );
    addTearDown(() => core.closeAccountRootKey(initialArk));
    final stateBlob = await core.sealDeviceState(
      key,
      identity,
      deviceId: _rawUuid(_deviceId1),
      keyVersion: 1,
      ark: initialArk,
      account: KelivoDeviceStateAccountBinding(userId: userId, keyEpoch: 1),
    );

    final epochOneState = await core.openDeviceState(key, stateBlob: stateBlob);
    addTearDown(() => core.closeDeviceIdentity(epochOneState.identity));
    final epochOneCipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: epochOneState.ark!,
      userId: _userId,
      currentKeyEpoch: 1,
    );
    addTearDown(epochOneCipher.close);

    const entityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'record-epoch-history',
    );
    final payload = Uint8List.fromList(<int>[1, 7, 9]);
    final epochOneRecord = await epochOneCipher.seal(
      entityKey: entityKey,
      payload: payload,
    );

    final epochTwoArk = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 2,
    );
    addTearDown(() => core.closeAccountRootKey(epochTwoArk));

    final currentState = await core.openDeviceState(key, stateBlob: stateBlob);
    addTearDown(() => core.closeDeviceIdentity(currentState.identity));
    await core.addAccountRootKeyEpoch(currentState.ark!, source: epochTwoArk);
    final currentCipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: currentState.ark!,
      userId: _userId,
      currentKeyEpoch: 2,
    );
    addTearDown(currentCipher.close);

    final epochTwoId = await currentCipher.deriveRecordId(entityKey);
    expect(epochTwoId, isNot(epochOneRecord.recordId));
    final opened = await currentCipher.open(
      _untrustedRecord(epochOneRecord),
      decode: (_, borrowed) => Uint8List.fromList(borrowed),
    );
    expect(opened, orderedEquals(payload));

    final prunedState = await core.openDeviceState(key, stateBlob: stateBlob);
    addTearDown(() => core.closeDeviceIdentity(prunedState.identity));
    await core.addAccountRootKeyEpoch(prunedState.ark!, source: epochTwoArk);
    await core.pruneAccountRootKeyEpoch(prunedState.ark!, keyEpoch: 1);
    final prunedCipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: prunedState.ark!,
      userId: _userId,
      currentKeyEpoch: 2,
    );
    addTearDown(prunedCipher.close);

    await expectLater(
      prunedCipher.open(
        _untrustedRecord(epochOneRecord),
        decode: (_, borrowed) => Uint8List.fromList(borrowed),
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.recordAuthenticationFailed,
        ),
      ),
    );
  });

  test('账户记录加密器接受完整正 uint32 密钥世代', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 0xffffffff,
    );
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 0xffffffff,
    );
    addTearDown(cipher.close);

    const entityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-max-epoch',
    );
    final sealed = await cipher.seal(
      entityKey: entityKey,
      payload: Uint8List.fromList(<int>[4, 2]),
    );
    final opened = await cipher.open(
      _untrustedRecord(sealed),
      decode: (_, payload) => Uint8List.fromList(payload),
    );

    expect(sealed.keyEpoch, 0xffffffff);
    expect(opened, orderedEquals(<int>[4, 2]));

    final overflowArk = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 1,
    );
    expect(
      () => E2eeAccountRecordCipher.takeOwnership(
        secureCore: core,
        accountRootKey: overflowArk,
        userId: _userId,
        currentKeyEpoch: 0x100000000,
      ),
      throwsA(isA<FormatException>()),
    );
    await core.closeAccountRootKey(overflowArk);
  });

  test('账户ARK租约只向严格匹配会话转移一次所有权', () async {
    const core = KelivoSecureCore();
    final root = await Directory.current.createTemp('.kelivo-key-lease-');
    addTearDown(() => root.delete(recursive: true));
    final store = DeviceStateBlobStore(installationRoot: root);
    final nonce = sha256
        .convert(utf8.encode(root.path))
        .toString()
        .substring(0, 16);
    final baseUrl = 'https://lease-$nonce.example.com';
    final loginName = 'lease-$nonce';
    final session = await _seedAccountKeyLeaseState(
      core: core,
      store: store,
      baseUrl: baseUrl,
      loginName: loginName,
    );

    final lease = await E2eeAccountKeyLease.open(
      session: session,
      deviceStateStore: store,
      secureCore: core,
    );
    expect(lease.deviceKeyVersion, 3);
    final ark = lease.takeAccountRootKeyOwnership();
    addTearDown(() async {
      try {
        await core.closeAccountRootKey(ark);
      } on StateError {
        // 测试正文可能已经关闭句柄；清理阶段只忽略该确定状态。
      }
    });

    expect(lease.takeAccountRootKeyOwnership, throwsStateError);
    await lease.close();
    await lease.close();
    final recordId = await core.deriveAccountRecordId(
      ark,
      keyEpoch: session.keyEpoch,
      canonicalEntityKey: Uint8List.fromList(utf8.encode('conversation:id')),
    );
    expect(recordId, hasLength(16));
    await core.closeAccountRootKey(ark);
  });

  test('账户ARK租约拒绝会话与设备状态任一绑定不一致', () async {
    const core = KelivoSecureCore();
    final root = await Directory.current.createTemp(
      'kelivo-key-lease-mismatch-',
    );
    addTearDown(() => root.delete(recursive: true));
    final store = DeviceStateBlobStore(installationRoot: root);
    final nonce = sha256
        .convert(utf8.encode(root.path))
        .toString()
        .substring(0, 16);
    final baseUrl = 'https://lease-$nonce.example.com';
    final loginName = 'lease-$nonce';
    final valid = await _seedAccountKeyLeaseState(
      core: core,
      store: store,
      baseUrl: baseUrl,
      loginName: loginName,
    );

    final mismatches = <CloudSyncAccountSession>[
      _accountKeyLeaseSession(baseUrl: baseUrl, loginName: '$loginName-other'),
      _accountKeyLeaseSession(
        baseUrl: 'https://other-$nonce.example.com',
        loginName: loginName,
      ),
      _accountKeyLeaseSession(
        baseUrl: baseUrl,
        loginName: loginName,
        userId: _accountContextId,
      ),
      _accountKeyLeaseSession(
        baseUrl: baseUrl,
        loginName: loginName,
        deviceId: _deviceId2,
      ),
      _accountKeyLeaseSession(
        baseUrl: baseUrl,
        loginName: loginName,
        keyEpoch: valid.keyEpoch + 1,
      ),
      _accountKeyLeaseSession(
        baseUrl: baseUrl,
        loginName: loginName,
        deviceKeyVersion: valid.deviceKeyVersion + 1,
      ),
    ];
    for (final mismatch in mismatches) {
      await expectLater(
        E2eeAccountKeyLease.open(
          session: mismatch,
          deviceStateStore: store,
          secureCore: core,
        ),
        throwsStateError,
      );
    }

    final unboundLoginName = 'unbound-$nonce';
    final unbound = await _seedAccountKeyLeaseState(
      core: core,
      store: store,
      baseUrl: baseUrl,
      loginName: unboundLoginName,
      bound: false,
    );
    await expectLater(
      E2eeAccountKeyLease.open(
        session: unbound,
        deviceStateStore: store,
        secureCore: core,
      ),
      throwsStateError,
    );

    final reopened = await E2eeAccountKeyLease.open(
      session: valid,
      deviceStateStore: store,
      secureCore: core,
    );
    await reopened.close();
  });

  test('账户ARK租约关闭幂等且关闭后保持失败关闭', () async {
    const core = KelivoSecureCore();
    final root = await Directory.current.createTemp('kelivo-key-lease-close-');
    addTearDown(() => root.delete(recursive: true));
    final store = DeviceStateBlobStore(installationRoot: root);
    final nonce = sha256
        .convert(utf8.encode(root.path))
        .toString()
        .substring(0, 16);
    final baseUrl = 'https://lease-$nonce.example.com';
    final loginName = 'lease-$nonce';
    final session = await _seedAccountKeyLeaseState(
      core: core,
      store: store,
      baseUrl: baseUrl,
      loginName: loginName,
    );
    final lease = await E2eeAccountKeyLease.open(
      session: session,
      deviceStateStore: store,
      secureCore: core,
    );

    await lease.close();
    await lease.close();
    expect(lease.takeAccountRootKeyOwnership, throwsStateError);
  });

  test('E2EE 同步 payload 递归排序对象键并保留数组顺序', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.toolEvent,
      entityId: 'message-1',
    );
    final first = <String, Object?>{
      'messageId': 'message-1',
      'events': <Object?>[
        <String, Object?>{
          'z': <Object?>[
            3,
            null,
            true,
            1.5,
            <String, Object?>{'b': '二', 'a': '一'},
          ],
          'a': 'value',
        },
      ],
    };
    final second = <String, Object?>{
      'events': <Object?>[
        <String, Object?>{
          'a': 'value',
          'z': <Object?>[
            3,
            null,
            true,
            1.5,
            <String, Object?>{'a': '一', 'b': '二'},
          ],
        },
      ],
      'messageId': 'message-1',
    };

    final firstBytes = E2eeSyncPayloadCodec.encode(
      entityKey: entityKey,
      payload: first,
    );
    final secondBytes = E2eeSyncPayloadCodec.encode(
      entityKey: entityKey,
      payload: second,
    );

    expect(firstBytes, orderedEquals(secondBytes));
    expect(
      utf8.decode(firstBytes),
      '{"payload":{"events":[{"a":"value","z":[3,null,true,1.5,{"a":"一","b":"二"}]}],"messageId":"message-1"},"recordType":"tool-event","version":2}',
    );
    final decoded = E2eeSyncPayloadCodec.decode(
      entityKey: entityKey,
      bytes: firstBytes,
    );
    expect(decoded, equals(second));
    expect(
      E2eeSyncPayloadCodec.encode(entityKey: entityKey, payload: decoded),
      orderedEquals(firstBytes),
    );
  });

  test('E2EE 同步 payload 解码结果递归不可变且不借用输入', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.toolEvent,
      entityId: 'message-1',
    );
    final bytes = E2eeSyncPayloadCodec.encode(
      entityKey: entityKey,
      payload: _validToolEventPayload(value: <String, Object?>{'nested': 1}),
    );
    final decoded = E2eeSyncPayloadCodec.decode(
      entityKey: entityKey,
      bytes: bytes,
    );
    bytes.fillRange(0, bytes.length, 0);

    final events = decoded['events'] as List<Object?>;
    final event = events.single as Map<String, Object?>;
    final value = event['value'] as Map<String, Object?>;
    expect(value['nested'], 1);
    expect(() => decoded['other'] = 2, throwsUnsupportedError);
    expect(() => events.add(2), throwsUnsupportedError);
    expect(() => value['nested'] = 2, throwsUnsupportedError);
  });

  test('E2EE 同步 payload 严格覆盖六类聊天记录 schema', () {
    final cases = <(SyncEntityKey, Map<String, Object?>)>[
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.conversation,
          entityId: 'conversation-1',
        ),
        _validConversationPayload(),
      ),
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.turn,
          entityId: 'turn-1',
        ),
        _validTurnPayload(),
      ),
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.message,
          entityId: 'message-1',
        ),
        _validMessagePayload(),
      ),
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.messageSelection,
          entityId: 'group-1',
        ),
        _validMessageSelectionPayload(),
      ),
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.toolEvent,
          entityId: 'message-1',
        ),
        _validToolEventPayload(),
      ),
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.thoughtSignature,
          entityId: 'message-1',
        ),
        _validThoughtSignaturePayload(),
      ),
    ];

    for (final (entityKey, payload) in cases) {
      final encoded = E2eeSyncPayloadCodec.encode(
        entityKey: entityKey,
        payload: payload,
      );
      expect(
        E2eeSyncPayloadCodec.decode(entityKey: entityKey, bytes: encoded),
        payload,
      );
    }
  });

  test('E2EE 消息 payload 接受上限内完整附件引用', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.message,
      entityId: 'message-1',
    );
    expect(e2eeSyncMaximumMessageAttachmentCount, 32);
    final attachments = List<Object?>.generate(
      e2eeSyncMaximumMessageAttachmentCount,
      _validMessageAttachment,
      growable: false,
    );
    final payload = <String, Object?>{
      ..._validMessagePayload(),
      'attachments': attachments,
    };

    final encoded = E2eeSyncPayloadCodec.encode(
      entityKey: entityKey,
      payload: payload,
    );
    final decoded = E2eeSyncPayloadCodec.decode(
      entityKey: entityKey,
      bytes: encoded,
    );

    expect(decoded['attachments'], attachments);
  });

  test('E2EE 消息 payload 在递归冻结前拒绝超限附件', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.message,
      entityId: 'message-1',
    );
    final attachmentLimitFailure = isA<FormatException>().having(
      (error) => error.message,
      'message',
      contains('$e2eeSyncMaximumMessageAttachmentCount'),
    );
    final oversizedAttachments = List<Object?>.generate(
      e2eeSyncMaximumMessageAttachmentCount + 1,
      _validMessageAttachment,
      growable: false,
    );

    expect(
      () => E2eeSyncPayloadCodec.encode(
        entityKey: entityKey,
        payload: <String, Object?>{
          ..._validMessagePayload(),
          'attachments': oversizedAttachments,
        },
      ),
      throwsA(attachmentLimitFailure),
    );
    expect(
      () => E2eeSyncPayloadCodec.encode(
        entityKey: entityKey,
        payload: <String, Object?>{
          ..._validMessagePayload(),
          'attachments': _LengthOnlyAttachments(),
        },
      ),
      throwsA(attachmentLimitFailure),
    );

    Object? deeplyNestedValue = true;
    for (var depth = 0; depth < 100; depth++) {
      deeplyNestedValue = <Object?>[deeplyNestedValue];
    }
    oversizedAttachments[0] = <String, Object?>{
      'unexpected': deeplyNestedValue,
    };
    final source = utf8.encode(
      jsonEncode(<String, Object?>{
        'payload': <String, Object?>{
          ..._validMessagePayload(),
          'attachments': oversizedAttachments,
        },
        'recordType': E2eeSyncChatRecordTypes.message,
        'version': e2eeSyncPayloadFormatVersion,
      }),
    );
    expect(
      () => E2eeSyncPayloadCodec.decode(
        entityKey: entityKey,
        bytes: Uint8List.fromList(source),
      ),
      throwsA(attachmentLimitFailure),
    );
  });

  test('E2EE 同步 payload 拒绝非规范编码与非法信封', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.thoughtSignature,
      entityId: 'message-1',
    );
    final invalidSources = <List<int>>[
      <int>[0xc3, 0x28],
      utf8.encode(
        '{"payload":{"messageId":"message-1","signature":"signature"}, "recordType":"thought-signature","version":1}',
      ),
      utf8.encode(
        '{"recordType":"thought-signature","payload":{"messageId":"message-1","signature":"signature"},"version":1}',
      ),
      utf8.encode(
        '{"payload":null,"recordType":"thought-signature","version":1}',
      ),
      utf8.encode(
        '{"extra":null,"payload":{},"recordType":"thought-signature","version":1}',
      ),
      utf8.encode(
        '{"payload":{},"recordType":"thought-signature","version":2}',
      ),
      utf8.encode(
        '{"payload":{},"recordType":"thought-signature","version":1.0}',
      ),
      utf8.encode(
        '{"payload":{"messageId":"message-1","signature":"signature"},"recordType":"tool-event","version":1}',
      ),
      utf8.encode('[]'),
    ];

    for (final source in invalidSources) {
      expect(
        () => E2eeSyncPayloadCodec.decode(
          entityKey: entityKey,
          bytes: Uint8List.fromList(source),
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('E2EE 同步 payload 拒绝非法值类型、键与非有限数值', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.toolEvent,
      entityId: 'message-1',
    );
    Object? deeplyNested = true;
    for (var depth = 0; depth < 100; depth++) {
      deeplyNested = <Object?>[deeplyNested];
    }
    final invalidValues = <Object?>[
      DateTime.utc(2026),
      <Object?, Object?>{1: 'value'},
      double.nan,
      double.infinity,
      double.negativeInfinity,
      String.fromCharCode(0xd800),
      <String, Object?>{String.fromCharCode(0xdc00): true},
      deeplyNested,
    ];

    for (final value in invalidValues) {
      expect(
        () => E2eeSyncPayloadCodec.encode(
          entityKey: entityKey,
          payload: _validToolEventPayload(value: value),
        ),
        throwsA(isA<FormatException>()),
      );
    }

    final nestedPrefix = List<String>.filled(100, '[').join();
    final nestedSuffix = List<String>.filled(100, ']').join();
    expect(
      () => E2eeSyncPayloadCodec.decode(
        entityKey: entityKey,
        bytes: Uint8List.fromList(
          utf8.encode(
            '{"payload":{"events":[{"value":$nestedPrefix'
            'true$nestedSuffix}],"messageId":"message-1"},'
            '"recordType":"tool-event","version":1}',
          ),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('E2EE 同步 payload 拒绝未知类型、额外字段与身份错配', () {
    expect(
      () => E2eeSyncPayloadCodec.encode(
        entityKey: const SyncEntityKey(
          entityType: 'unknown-record',
          entityId: 'record-1',
        ),
        payload: const <String, Object?>{},
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => E2eeSyncPayloadCodec.encode(
        entityKey: const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.conversation,
          entityId: 'conversation-1',
        ),
        payload: <String, Object?>{
          ..._validConversationPayload(),
          'extra': true,
        },
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => E2eeSyncPayloadCodec.encode(
        entityKey: const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.messageSelection,
          entityId: 'other-group',
        ),
        payload: _validMessageSelectionPayload(),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('账户记录加密器拒绝篡改、错误标识、未来世代与越界内容', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 7,
    );
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    addTearDown(cipher.close);

    const entityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-1',
    );
    const otherEntityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-2',
    );
    final sealed = await cipher.seal(
      entityKey: entityKey,
      payload: Uint8List(0),
    );
    final otherId = await cipher.deriveRecordId(otherEntityKey);
    final tampered = Uint8List.fromList(sealed.ciphertext);
    tampered[tampered.length - 1] ^= 1;

    await expectLater(
      cipher.open<Object?>(
        _untrustedRecord(sealed, ciphertext: tampered),
        decode: (_, _) => null,
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
    await expectLater(
      cipher.open<Object?>(
        _untrustedRecord(
          sealed,
          recordId: E2eeUntrustedAccountRecordId.fromTransport(
            otherId.wireValue,
          ),
        ),
        decode: (_, _) => null,
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
    await expectLater(
      cipher.open<Object?>(
        _untrustedRecord(sealed, keyEpoch: 8),
        decode: (_, _) => null,
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      cipher.deriveRecordId(
        const SyncEntityKey(entityType: 'Conversation', entityId: '1'),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      cipher.deriveRecordId(
        SyncEntityKey(
          entityType: 'message',
          entityId: List<String>.filled(1025, 'a').join(),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      cipher.deriveRecordId(
        SyncEntityKey(
          entityType: 'message',
          entityId: String.fromCharCode(0xd800),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      cipher.seal(
        entityKey: entityKey,
        payload: Uint8List(e2eeAccountRecordMaxCiphertextBytes),
      ),
      throwsA(isA<ArgumentError>()),
    );

    await cipher.close();
    await expectLater(
      cipher.deriveRecordId(entityKey),
      throwsA(isA<StateError>()),
    );
  });

  test('账户记录加密器拒绝跨账户句柄包装与帧内实体键替换', () async {
    const core = KelivoSecureCore();
    const firstKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-1',
    );
    const secondKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-2',
    );

    final aadArk = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 7,
    );
    expect(
      () => E2eeAccountRecordCipher.takeOwnership(
        secureCore: core,
        accountRootKey: aadArk,
        userId: _accountContextId,
        currentKeyEpoch: 7,
      ),
      throwsA(isA<FormatException>()),
    );
    await core.closeAccountRootKey(aadArk);

    final identityArk = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 7,
    );
    final mismatchedRecord = await _sealRawAccountRecord(
      core: core,
      ark: identityArk,
      recordIdKey: firstKey,
      frameKey: secondKey,
      userId: _userId,
    );
    final identityCipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: identityArk,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    addTearDown(identityCipher.close);
    await expectLater(
      identityCipher.open<Object?>(mismatchedRecord, decode: (_, _) => null),
      throwsA(isA<FormatException>()),
    );
  });

  test('不可信账户记录信封严格校验传输边界', () {
    expect(
      () => E2eeUntrustedAccountRecordId.fromTransport(
        'A0000000-0000-4000-8000-000000000001',
      ),
      throwsA(isA<FormatException>()),
    );
    final recordId = E2eeUntrustedAccountRecordId.fromTransport(_recordId1);
    final validEpochs = <int>[1, 0xffffffff];
    for (final keyEpoch in validEpochs) {
      expect(
        E2eeUntrustedAccountRecordEnvelope.fromTransport(
          recordId: recordId,
          envelopeVersion: e2eeAccountRecordEnvelopeVersion,
          keyEpoch: keyEpoch,
          ciphertext: Uint8List.fromList(<int>[1]),
        ).keyEpoch,
        keyEpoch,
      );
    }
    for (final invalid in <({int version, int epoch, Uint8List ciphertext})>[
      (version: 2, epoch: 1, ciphertext: Uint8List.fromList(<int>[1])),
      (version: 1, epoch: 0, ciphertext: Uint8List.fromList(<int>[1])),
      (
        version: 1,
        epoch: 0x100000000,
        ciphertext: Uint8List.fromList(<int>[1]),
      ),
      (version: 1, epoch: 1, ciphertext: Uint8List(0)),
      (
        version: 1,
        epoch: 1,
        ciphertext: Uint8List(e2eeAccountRecordMaxCiphertextBytes + 1),
      ),
    ]) {
      expect(
        () => E2eeUntrustedAccountRecordEnvelope.fromTransport(
          recordId: recordId,
          envelopeVersion: invalid.version,
          keyEpoch: invalid.epoch,
          ciphertext: invalid.ciphertext,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('v3 推送接受完整 uint32 keyEpoch 并解析三类结果', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 0xffffffff,
    );
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 0xffffffff,
    );
    final stateCodec = E2eeAccountRecordStateCodec.takeOwnership(cipher);
    addTearDown(stateCodec.close);
    final firstState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(
        entityType: 'conversation',
        entityId: 'conversation-1',
      ),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId1,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final secondState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(
        entityType: 'conversation',
        entityId: 'conversation-2',
      ),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId2,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[7, 8, 9]),
    );
    final thirdState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(
        entityType: 'message',
        entityId: 'message-1',
      ),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId3,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[4, 5, 6]),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pushFuture = client.pushRecordsWithToken(<CloudSyncRecordMutation>[
      CloudSyncPutRecordMutation(
        mutationId: _mutationId1,
        expectedRevision: 0,
        state: firstState,
      ),
      CloudSyncPutRecordMutation(
        mutationId: _mutationId2,
        expectedRevision: 3,
        state: secondState,
      ),
      CloudSyncPutRecordMutation(
        mutationId: _mutationId3,
        expectedRevision: 2,
        state: thirdState,
      ),
    ], token: _fullToken);
    client.setToken(_otherFullToken);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/record/push');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer $_fullTokenValue',
    );
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{
        'mutations': <Object?>[
          <String, Object?>{
            'mutationId': _mutationId1,
            'recordId': firstState.record.recordId.wireValue,
            'expectedRevision': 0,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 0xffffffff,
            'ciphertext': _encodedRecordCiphertext(firstState.record),
          },
          <String, Object?>{
            'mutationId': _mutationId2,
            'recordId': secondState.record.recordId.wireValue,
            'expectedRevision': 3,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 0xffffffff,
            'ciphertext': _encodedRecordCiphertext(secondState.record),
          },
          <String, Object?>{
            'mutationId': _mutationId3,
            'recordId': thirdState.record.recordId.wireValue,
            'expectedRevision': 2,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 0xffffffff,
            'ciphertext': _encodedRecordCiphertext(thirdState.record),
          },
        ],
      },
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'mutationId': _mutationId1,
              'status': 'applied',
              'revision': 1,
              'changeSeq': 11,
            },
            <String, Object?>{
              'mutationId': _mutationId2,
              'status': 'conflict',
              'currentRevision': 4,
            },
            <String, Object?>{
              'mutationId': _mutationId3,
              'status': 'rejected',
              'errorCode': 'SYNC_RECORD_REJECTED',
            },
          ],
        },
      }),
    );
    await request.response.close();

    final results = await pushFuture;
    expect(
      results[0],
      isA<CloudSyncAppliedMutationResult>()
          .having((result) => result.revision, 'revision', 1)
          .having((result) => result.changeSeq, 'changeSeq', 11),
    );
    expect(
      results[1],
      isA<CloudSyncConflictMutationResult>().having(
        (result) => result.currentRevision,
        'currentRevision',
        4,
      ),
    );
    expect(
      results[2],
      isA<CloudSyncRejectedMutationResult>().having(
        (result) => result.errorCode,
        'errorCode',
        'SYNC_RECORD_REJECTED',
      ),
    );
  });

  test('v3 推送在发网前拒绝 mutationId 与认证 operationId 不一致', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 7,
    );
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    final stateCodec = E2eeAccountRecordStateCodec.takeOwnership(cipher);
    addTearDown(stateCodec.close);
    final state = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(
        entityType: 'conversation',
        entityId: 'conversation-1',
      ),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId1,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[1, 2, 3]),
    );

    expect(
      () => CloudSyncPutRecordMutation(
        mutationId: _mutationId2,
        expectedRevision: 0,
        state: state,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.name,
          'name',
          'mutationId',
        ),
      ),
    );
  });

  test('v3 增量拉取接受完整 uint32 keyEpoch 并保持 put 密文不透明', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChangesWithToken(
      token: _fullToken,
      cursor: 'cursor-1',
      limit: 1,
    );
    client.setToken(_otherFullToken);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/change/pull');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer $_fullTokenValue',
    );
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'cursor': 'cursor-1', 'limit': 1},
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'changeSeq': 12,
              'operation': 'put',
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 0xffffffff,
              'ciphertext': 'AQID',
              'ciphertextBytes': 3,
              'updatedAt': '2026-07-19T05:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
            },
          ],
          'nextCursor': 'cursor-2',
          'hasMore': true,
          'resetRequired': false,
        },
      }),
    );
    await request.response.close();

    final result = await pullFuture;
    expect(result, isA<CloudSyncChangePage>());
    final page = result as CloudSyncChangePage;
    expect(page.nextCursor, 'cursor-2');
    expect(page.hasMore, isTrue);
    expect(
      page.changes[0],
      isA<CloudSyncPutRecordChange>()
          .having((change) => change.changeSeq, 'changeSeq', 12)
          .having((change) => change.recordId.wireValue, 'recordId', _recordId1)
          .having((change) => change.revision, 'revision', 2)
          .having((change) => change.record.keyEpoch, 'keyEpoch', 0xffffffff)
          .having(
            (change) => change.record.ciphertext,
            'ciphertext',
            orderedEquals(<int>[1, 2, 3]),
          )
          .having(
            (change) => change.updatedByDeviceId,
            'updatedByDeviceId',
            _deviceId1,
          ),
    );
  });

  test('v3 增量拉取拒绝包含 raw delete 的整页响应', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges(cursor: 'cursor-1', limit: 2);
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'changeSeq': 12,
              'operation': 'put',
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'AQID',
              'ciphertextBytes': 3,
              'updatedAt': '2026-07-19T05:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
            },
            <String, Object?>{
              'changeSeq': 13,
              'operation': 'delete',
              'recordId': _recordId2,
              'revision': 4,
              'envelopeVersion': null,
              'keyEpoch': null,
              'ciphertext': null,
              'ciphertextBytes': 0,
              'deletedAt': '2026-07-19T05:01:00.000Z',
              'updatedAt': '2026-07-19T05:01:00.000Z',
              'updatedByDeviceId': null,
            },
          ],
          'nextCursor': 'cursor-2',
          'hasMore': true,
          'resetRequired': false,
        },
      }),
    );
    await request.response.close();

    await expectLater(
      pullFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('v3 增量拉取显式返回服务端要求重置游标', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges();
    final request = await requestFuture;
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'limit': 10},
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'changes': <Object?>[],
          'nextCursor': null,
          'hasMore': false,
          'resetRequired': true,
        },
      }),
    );
    await request.response.close();

    expect(await pullFuture, isA<CloudSyncResetRequired>());
  });

  test('v3 增量拉取拒绝携带伪游标的 reset 响应', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges();
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'changes': <Object?>[],
          'nextCursor': 'forged-reset-cursor',
          'hasMore': false,
          'resetRequired': true,
        },
      }),
    );
    await request.response.close();

    await expectLater(
      pullFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('v3 快照首次拉取允许同一记录的非空完整有序历史', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullSnapshotWithToken(
      token: _fullToken,
      limit: 2,
    );
    client.setToken(_otherFullToken);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/snapshot/pull');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer $_fullTokenValue',
    );
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'limit': 2},
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'dataRekeyPhase': 'ready',
          'records': <Object?>[
            <String, Object?>{
              'recordId': _recordId1,
              'revision': 1,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'AQID',
              'ciphertextBytes': 3,
              'updatedAt': '2026-07-19T04:59:00.000Z',
              'updatedByDeviceId': _deviceId1,
              'lastChangeSeq': 11,
            },
            <String, Object?>{
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'BAUG',
              'ciphertextBytes': 3,
              'updatedAt': '2026-07-19T05:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
              'lastChangeSeq': 12,
            },
          ],
          'nextSnapshotCursor': null,
          'syncCursor': 'sync-13',
          'hasMore': false,
        },
      }),
    );
    await request.response.close();

    final page = await pullFuture;
    expect(page.nextSnapshotCursor, isNull);
    expect(page.syncCursor, 'sync-13');
    expect(page.hasMore, isFalse);
    expect(
      page.records[1],
      isA<CloudSyncEncryptedRecord>()
          .having((record) => record.recordId.wireValue, 'recordId', _recordId1)
          .having((record) => record.revision, 'revision', 2)
          .having((record) => record.lastChangeSeq, 'lastChangeSeq', 12)
          .having((record) => record.record.keyEpoch, 'keyEpoch', 7)
          .having(
            (record) => record.record.ciphertext,
            'ciphertext',
            orderedEquals(<int>[4, 5, 6]),
          ),
    );
  });

  test('v3 快照拉取拒绝乱序历史', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullSnapshot(limit: 2);
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'records': <Object?>[
            for (final sequence in <int>[12, 11])
              <String, Object?>{
                'recordId': _recordId1,
                'revision': sequence - 10,
                'envelopeVersion': 1,
                'keyEpoch': 7,
                'ciphertext': 'AQID',
                'ciphertextBytes': 3,
                'updatedAt': '2026-07-19T05:00:00.000Z',
                'updatedByDeviceId': _deviceId1,
                'lastChangeSeq': sequence,
              },
          ],
          'nextSnapshotCursor': null,
          'syncCursor': 'sync-12',
          'hasMore': false,
        },
      }),
    );
    await request.response.close();

    await expectLater(
      pullFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('v3 快照拉取拒绝包含 raw deleted 的整页响应', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullSnapshot(
      snapshotCursor: 'snapshot-1',
      limit: 2,
    );
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'records': <Object?>[
            <String, Object?>{
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'BAUG',
              'ciphertextBytes': 3,
              'updatedAt': '2026-07-19T05:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
              'lastChangeSeq': 12,
            },
            <String, Object?>{
              'recordId': _recordId2,
              'revision': 4,
              'envelopeVersion': null,
              'keyEpoch': null,
              'ciphertext': null,
              'ciphertextBytes': 0,
              'deletedAt': '2026-07-19T05:01:00.000Z',
              'updatedAt': '2026-07-19T05:01:00.000Z',
              'updatedByDeviceId': null,
              'lastChangeSeq': 13,
            },
          ],
          'nextSnapshotCursor': null,
          'syncCursor': 'sync-13',
          'hasMore': false,
        },
      }),
    );
    await request.response.close();

    await expectLater(
      pullFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('v3 HTTP 边界拒绝非空增量页与快照页原地游标', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/sync/change/pull') {
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'changes': <Object?>[
                <String, Object?>{
                  'changeSeq': 12,
                  'operation': 'put',
                  'recordId': _recordId1,
                  'revision': 2,
                  'envelopeVersion': 1,
                  'keyEpoch': 7,
                  'ciphertext': 'AQID',
                  'ciphertextBytes': 3,
                  'updatedAt': '2026-07-19T05:00:00.000Z',
                  'updatedByDeviceId': _deviceId1,
                },
              ],
              'nextCursor': 'cursor-stuck',
              'hasMore': true,
              'resetRequired': false,
            },
          }),
        );
      } else {
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'records': <Object?>[
                <String, Object?>{
                  'recordId': _recordId1,
                  'revision': 2,
                  'envelopeVersion': 1,
                  'keyEpoch': 7,
                  'ciphertext': 'AQID',
                  'ciphertextBytes': 3,
                  'updatedAt': '2026-07-19T05:00:00.000Z',
                  'updatedByDeviceId': _deviceId1,
                  'lastChangeSeq': 12,
                },
              ],
              'nextSnapshotCursor': 'snapshot-stuck',
              'syncCursor': null,
              'hasMore': true,
            },
          }),
        );
      }
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final invalidResponse = throwsA(
      isA<CloudSyncException>()
          .having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.invalidResponse,
          )
          .having((error) => error.retryable, 'retryable', isFalse),
    );

    await expectLater(
      client.pullChanges(cursor: 'cursor-stuck', limit: 1),
      invalidResponse,
    );
    await expectLater(
      client.pullSnapshot(snapshotCursor: 'snapshot-stuck', limit: 1),
      invalidResponse,
    );
  });

  test('v3 推送在发网前拒绝非法标识与批量边界', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 7,
    );
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    final stateCodec = E2eeAccountRecordStateCodec.takeOwnership(cipher);
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    addTearDown(() async {
      client.close(force: true);
      await stateCodec.close();
    });
    final smallState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(entityType: 'conversation', entityId: '1'),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId1,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List(0),
    );
    final firstHalfState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(entityType: 'message', entityId: '1'),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId1,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List(524200),
    );
    final secondHalfState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(entityType: 'message', entityId: '2'),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId2,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List(524200),
    );
    final oversizedBatch = List<CloudSyncRecordMutation>.generate(
      11,
      (_) => CloudSyncPutRecordMutation(
        mutationId: _mutationId1,
        expectedRevision: 1,
        state: smallState,
      ),
    );
    final invalidCalls = <(String, Object? Function())>[
      ('空批次', () => client.pushRecords(const <CloudSyncRecordMutation>[])),
      ('超过十条', () => client.pushRecords(oversizedBatch)),
      (
        '批次密文总量超过一 MiB',
        () => client.pushRecords(<CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            expectedRevision: 0,
            state: firstHalfState,
          ),
          CloudSyncPutRecordMutation(
            mutationId: _mutationId2,
            expectedRevision: 0,
            state: secondHalfState,
          ),
        ]),
      ),
    ];

    for (final invalidCall in invalidCalls) {
      expect(
        invalidCall.$2,
        throwsA(
          isA<CloudSyncException>()
              .having(
                (error) => error.kind,
                'kind',
                CloudSyncFailureKind.validation,
              )
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
        reason: invalidCall.$1,
      );
    }
  });

  test('v3 拉取在发网前拒绝非法分页与游标边界', () {
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    addTearDown(() => client.close(force: true));
    final oversizedCursor = List<String>.filled(4097, 'a').join();
    final invalidCalls = <(String, Object? Function())>[
      ('增量 limit 下界', () => client.pullChanges(limit: 0)),
      ('增量 limit 上界', () => client.pullChanges(limit: 11)),
      ('增量空游标', () => client.pullChanges(cursor: '')),
      ('增量超长游标', () => client.pullChanges(cursor: oversizedCursor)),
      ('快照 limit 下界', () => client.pullSnapshot(limit: 0)),
      ('快照 limit 上界', () => client.pullSnapshot(limit: 11)),
      ('快照空游标', () => client.pullSnapshot(snapshotCursor: '')),
      ('快照超长游标', () => client.pullSnapshot(snapshotCursor: oversizedCursor)),
    ];

    for (final invalidCall in invalidCalls) {
      expect(
        invalidCall.$2,
        throwsA(
          isA<CloudSyncException>().having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.validation,
          ),
        ),
        reason: invalidCall.$1,
      );
    }
  });

  test('v3 拒绝密文长度、分页数量或最终水位无效的响应', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var changeRequestCount = 0;
    final subscription = server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/sync/change/pull') {
        changeRequestCount++;
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'changes': <Object?>[
                <String, Object?>{
                  'changeSeq': 12,
                  'operation': 'put',
                  'recordId': _recordId1,
                  'revision': 2,
                  'envelopeVersion': 1,
                  'keyEpoch': 7,
                  'ciphertext': changeRequestCount == 2 ? 'AQID=' : 'AQID',
                  'ciphertextBytes': changeRequestCount == 1 ? 4 : 3,
                  'updatedAt': '2026-07-19T05:00:00.000Z',
                  'updatedByDeviceId': _deviceId1,
                },
                if (changeRequestCount > 2)
                  <String, Object?>{
                    'changeSeq': 13,
                    'operation': 'delete',
                    'recordId': _recordId2,
                    'revision': 4,
                    'envelopeVersion': null,
                    'keyEpoch': null,
                    'ciphertext': null,
                    'ciphertextBytes': 0,
                    'deletedAt': '2026-07-19T05:01:00.000Z',
                    'updatedAt': '2026-07-19T05:01:00.000Z',
                    'updatedByDeviceId': null,
                  },
              ],
              'nextCursor': 'cursor-2',
              'hasMore': false,
              'resetRequired': false,
            },
          }),
        );
      } else {
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'records': <Object?>[],
              'nextSnapshotCursor': null,
              'syncCursor': null,
              'hasMore': false,
            },
          }),
        );
      }
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final invalidResponse = throwsA(
      isA<CloudSyncException>()
          .having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.invalidResponse,
          )
          .having((error) => error.retryable, 'retryable', isFalse),
    );
    for (final request in <Future<Object?> Function()>[
      () => client.pullChanges(),
      () => client.pullChanges(),
      () => client.pullChanges(limit: 1),
      () => client.pullSnapshot(),
    ]) {
      await expectLater(request(), invalidResponse);
    }
  });

  test('v3 附件创建显式冻结完整会话令牌且只发送密文元数据', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _otherFullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final createFuture = client.createAttachmentUpload(
      token: _fullToken,
      request: CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        chunkKeyEpoch: 0xffffffff,
        manifestKeyEpoch: 0xffffffff,
        manifestRevision: 1,
        chunkCount: 2,
        totalCiphertextBytes: 5,
      ),
    );
    client.setToken(_otherFullToken);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/attachment/upload/create');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer $_fullTokenValue',
    );
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{
        'mutationId': _mutationId1,
        'attachmentId': _attachmentId,
        'chunkKeyEpoch': 0xffffffff,
        'manifestKeyEpoch': 0xffffffff,
        'manifestRevision': 1,
        'chunkCount': 2,
        'totalCiphertextBytes': 5,
      },
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'attachmentId': _attachmentId,
          'uploadId': _uploadId,
          'chunkKeyEpoch': 0xffffffff,
          'manifestKeyEpoch': 0xffffffff,
          'manifestRevision': 1,
          'chunkCount': 2,
          'totalCiphertextBytes': 5,
          'status': 'open',
          'createdAt': '2026-07-29T00:00:00.000Z',
        },
      }),
    );
    await request.response.close();

    final upload = await createFuture;
    expect(upload.identity.attachmentId, _attachmentId);
    expect(upload.identity.uploadId, _uploadId);
    expect(upload.identity.chunkKeyEpoch, 0xffffffff);
    expect(upload.identity.manifestKeyEpoch, 0xffffffff);
    expect(upload.identity.manifestRevision, 1);
    expect(upload.chunkCount, 2);
    expect(upload.totalCiphertextBytes, 5);
    expect(upload.createdAt, DateTime.utc(2026, 7, 29));
  });

  test('v3 附件分块、提交、清单、下载和删除保持不透明密文合同', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await requests.cancel();
      await server.close(force: true);
    });
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: 5,
      manifestKeyEpoch: 7,
      manifestRevision: 3,
    );
    final chunk = CloudSyncAttachmentChunkIdentity(
      identity: identity,
      chunkIndex: 0,
    );

    final putFuture = client.putAttachmentChunk(
      token: _fullToken,
      request: CloudSyncAttachmentPutChunkRequest(
        mutationId: _mutationId1,
        chunk: chunk,
        ciphertext: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );
    final putRequest = await _nextAttachmentRequest(requests);
    await _expectAttachmentRequest(
      putRequest,
      path: '/api/sync/attachment/chunk/put',
      body: <String, Object?>{
        'mutationId': _mutationId1,
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 5,
        'chunkIndex': 0,
        'ciphertext': 'AQID',
      },
    );
    await _writeJsonResponse(putRequest, <String, Object?>{
      'data': <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 5,
        'chunkIndex': 0,
        'ciphertextBytes': 3,
        'status': 'stored',
      },
    });
    final stored = await putFuture;
    expect(stored.chunk, same(chunk));
    expect(stored.ciphertextBytes, 3);

    final commitFuture = client.commitAttachmentUpload(
      token: _fullToken,
      request: CloudSyncAttachmentCommitUploadRequest(
        mutationId: _mutationId2,
        identity: identity,
        manifestCiphertext: Uint8List.fromList(<int>[4, 5]),
        chunks: <CloudSyncAttachmentManifestChunk>[
          CloudSyncAttachmentManifestChunk(chunkIndex: 0, ciphertextBytes: 3),
        ],
      ),
    );
    final commitRequest = await _nextAttachmentRequest(requests);
    await _expectAttachmentRequest(
      commitRequest,
      path: '/api/sync/attachment/upload/commit',
      body: <String, Object?>{
        'mutationId': _mutationId2,
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'manifestKeyEpoch': 7,
        'manifestRevision': 3,
        'manifestCiphertext': 'BAU',
        'chunks': <Object?>[
          <String, Object?>{'chunkIndex': 0, 'ciphertextBytes': 3},
        ],
      },
    );
    await _writeJsonResponse(commitRequest, <String, Object?>{
      'data': <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 5,
        'manifestKeyEpoch': 7,
        'manifestRevision': 3,
        'status': 'committed',
        'committedAt': '2026-07-29T00:01:00.000Z',
      },
    });
    final committed = await commitFuture;
    expect(committed.identity.attachmentId, _attachmentId);
    expect(committed.committedAt, DateTime.utc(2026, 7, 29, 0, 1));

    final manifestFuture = client.getAttachmentManifest(
      token: _fullToken,
      identity: identity,
    );
    final manifestRequest = await _nextAttachmentRequest(requests);
    await _expectAttachmentRequest(
      manifestRequest,
      path: '/api/sync/attachment/manifest/get',
      body: <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'manifestKeyEpoch': 7,
        'manifestRevision': 3,
      },
    );
    await _writeJsonResponse(manifestRequest, <String, Object?>{
      'data': <String, Object?>{
        'dataRekeyPhase': 'ready',
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 5,
        'manifestKeyEpoch': 7,
        'manifestRevision': 3,
        'chunkCount': 1,
        'totalCiphertextBytes': 3,
        'manifestCiphertext': 'BAU',
        'manifestCiphertextBytes': 2,
        'chunks': <Object?>[
          <String, Object?>{'chunkIndex': 0, 'ciphertextBytes': 3},
        ],
        'committedAt': '2026-07-29T00:01:00.000Z',
      },
    });
    final manifest = await manifestFuture;
    expect(manifest.identity.uploadId, _uploadId);
    expect(manifest.manifestCiphertext, orderedEquals(<int>[4, 5]));
    expect(manifest.chunks.single.ciphertextBytes, 3);

    final getChunkFuture = client.getAttachmentChunk(
      token: _fullToken,
      chunk: chunk,
    );
    final getChunkRequest = await _nextAttachmentRequest(requests);
    await _expectAttachmentRequest(
      getChunkRequest,
      path: '/api/sync/attachment/chunk/get',
      body: <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 5,
        'chunkIndex': 0,
      },
    );
    await _writeJsonResponse(getChunkRequest, <String, Object?>{
      'data': <String, Object?>{
        'dataRekeyPhase': 'ready',
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 5,
        'chunkIndex': 0,
        'ciphertext': 'AQID',
        'ciphertextBytes': 3,
      },
    });
    final downloaded = await getChunkFuture;
    expect(downloaded.chunk, same(chunk));
    expect(downloaded.ciphertext, orderedEquals(<int>[1, 2, 3]));

    final deleteFuture = client.deleteAttachment(
      token: _fullToken,
      request: CloudSyncAttachmentDeleteRequest(
        mutationId: _mutationId3,
        identity: identity,
      ),
    );
    final deleteRequest = await _nextAttachmentRequest(requests);
    await _expectAttachmentRequest(
      deleteRequest,
      path: '/api/sync/attachment/record/delete',
      body: <String, Object?>{
        'mutationId': _mutationId3,
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'manifestKeyEpoch': 7,
        'manifestRevision': 3,
      },
    );
    await _writeJsonResponse(deleteRequest, <String, Object?>{
      'data': <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 5,
        'manifestKeyEpoch': 7,
        'manifestRevision': 3,
        'status': 'deleted',
        'deletedAt': '2026-07-29T00:02:00.000Z',
      },
    });
    final deleted = await deleteFuture;
    expect(deleted.identity.chunkKeyEpoch, 5);
    expect(deleted.identity.manifestKeyEpoch, 7);
    expect(deleted.identity.manifestRevision, 3);
    expect(deleted.deletedAt, DateTime.utc(2026, 7, 29, 0, 2));
  });

  test('v3 附件强类型精确执行服务端大小与 uint32 边界', () {
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: 0xffffffff,
      manifestKeyEpoch: 0xffffffff,
      manifestRevision: 1,
    );
    final maximumCreate = CloudSyncAttachmentCreateUploadRequest(
      mutationId: _mutationId1,
      attachmentId: _attachmentId,
      chunkKeyEpoch: 0xffffffff,
      manifestKeyEpoch: 0xffffffff,
      manifestRevision: 1,
      chunkCount: cloudSyncMaximumAttachmentChunkCount,
      totalCiphertextBytes: cloudSyncMaximumAttachmentTotalCiphertextBytes,
    );
    expect(maximumCreate.chunkKeyEpoch, 0xffffffff);
    expect(maximumCreate.manifestKeyEpoch, 0xffffffff);
    expect(maximumCreate.manifestRevision, 1);
    expect(maximumCreate.totalCiphertextBytes, 1000 * 4 * 1024 * 1024);

    final chunkSource = Uint8List(
      cloudSyncMaximumAttachmentChunkCiphertextBytes,
    )..first = 1;
    final maximumChunk = CloudSyncAttachmentPutChunkRequest(
      mutationId: _mutationId2,
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: cloudSyncMaximumAttachmentChunkCount - 1,
      ),
      ciphertext: chunkSource,
    );
    chunkSource.first = 9;
    expect(maximumChunk.ciphertext.first, 1);
    expect(() => maximumChunk.ciphertext.first = 2, throwsUnsupportedError);

    final manifestSource = Uint8List(
      cloudSyncMaximumAttachmentManifestCiphertextBytes,
    )..first = 3;
    final chunkDescriptors = List<CloudSyncAttachmentManifestChunk>.generate(
      cloudSyncMaximumAttachmentChunkCount,
      (index) => CloudSyncAttachmentManifestChunk(
        chunkIndex: index,
        ciphertextBytes: cloudSyncMaximumAttachmentChunkCiphertextBytes,
      ),
    );
    final maximumCommit = CloudSyncAttachmentCommitUploadRequest(
      mutationId: _mutationId3,
      identity: identity,
      manifestCiphertext: manifestSource,
      chunks: chunkDescriptors,
    );
    manifestSource.first = 8;
    chunkDescriptors.clear();
    expect(maximumCommit.manifestCiphertext.first, 3);
    expect(
      maximumCommit.chunks,
      hasLength(cloudSyncMaximumAttachmentChunkCount),
    );

    final invalidValues = <Object? Function()>[
      () => CloudSyncAttachmentIdentity(
        attachmentId: _attachmentId,
        uploadId: _uploadId,
        chunkKeyEpoch: 0,
        manifestKeyEpoch: 1,
        manifestRevision: 2,
      ),
      () => CloudSyncAttachmentIdentity(
        attachmentId: _attachmentId,
        uploadId: _uploadId,
        chunkKeyEpoch: 0x100000000,
        manifestKeyEpoch: 0x100000000,
        manifestRevision: 1,
      ),
      () => CloudSyncAttachmentIdentity(
        attachmentId: _attachmentId,
        uploadId: _uploadId,
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 8,
        manifestRevision: 1,
      ),
      () => CloudSyncAttachmentIdentity(
        attachmentId: _attachmentId,
        uploadId: _uploadId,
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 7,
        manifestRevision: 0,
      ),
      () => CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        chunkKeyEpoch: 1,
        manifestKeyEpoch: 2,
        manifestRevision: 1,
        chunkCount: 1,
        totalCiphertextBytes: 1,
      ),
      () => CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        chunkKeyEpoch: 1,
        manifestKeyEpoch: 1,
        manifestRevision: 2,
        chunkCount: 1,
        totalCiphertextBytes: 1,
      ),
      () => CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        chunkKeyEpoch: 1,
        manifestKeyEpoch: 1,
        manifestRevision: 1,
        chunkCount: 0,
        totalCiphertextBytes: 1,
      ),
      () => CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        chunkKeyEpoch: 1,
        manifestKeyEpoch: 1,
        manifestRevision: 1,
        chunkCount: cloudSyncMaximumAttachmentChunkCount + 1,
        totalCiphertextBytes: cloudSyncMaximumAttachmentChunkCount + 1,
      ),
      () => CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        chunkKeyEpoch: 1,
        manifestKeyEpoch: 1,
        manifestRevision: 1,
        chunkCount: 2,
        totalCiphertextBytes: 1,
      ),
      () => CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        chunkKeyEpoch: 1,
        manifestKeyEpoch: 1,
        manifestRevision: 1,
        chunkCount: 1,
        totalCiphertextBytes:
            cloudSyncMaximumAttachmentChunkCiphertextBytes + 1,
      ),
      () =>
          CloudSyncAttachmentChunkIdentity(identity: identity, chunkIndex: -1),
      () => CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: cloudSyncMaximumAttachmentChunkCount,
      ),
      () => CloudSyncAttachmentPutChunkRequest(
        mutationId: _mutationId1,
        chunk: CloudSyncAttachmentChunkIdentity(
          identity: identity,
          chunkIndex: 0,
        ),
        ciphertext: Uint8List(0),
      ),
      () => CloudSyncAttachmentPutChunkRequest(
        mutationId: _mutationId1,
        chunk: CloudSyncAttachmentChunkIdentity(
          identity: identity,
          chunkIndex: 0,
        ),
        ciphertext: Uint8List(
          cloudSyncMaximumAttachmentChunkCiphertextBytes + 1,
        ),
      ),
      () => CloudSyncAttachmentCommitUploadRequest(
        mutationId: _mutationId1,
        identity: identity,
        manifestCiphertext: Uint8List(0),
        chunks: <CloudSyncAttachmentManifestChunk>[
          CloudSyncAttachmentManifestChunk(chunkIndex: 0, ciphertextBytes: 1),
        ],
      ),
      () => CloudSyncAttachmentCommitUploadRequest(
        mutationId: _mutationId1,
        identity: identity,
        manifestCiphertext: Uint8List(
          cloudSyncMaximumAttachmentManifestCiphertextBytes + 1,
        ),
        chunks: <CloudSyncAttachmentManifestChunk>[
          CloudSyncAttachmentManifestChunk(chunkIndex: 0, ciphertextBytes: 1),
        ],
      ),
      () => CloudSyncAttachmentCommitUploadRequest(
        mutationId: _mutationId1,
        identity: identity,
        manifestCiphertext: Uint8List.fromList(<int>[1]),
        chunks: const <CloudSyncAttachmentManifestChunk>[],
      ),
      () => CloudSyncAttachmentCommitUploadRequest(
        mutationId: _mutationId1,
        identity: identity,
        manifestCiphertext: Uint8List.fromList(<int>[1]),
        chunks: <CloudSyncAttachmentManifestChunk>[
          CloudSyncAttachmentManifestChunk(chunkIndex: 1, ciphertextBytes: 1),
        ],
      ),
    ];
    for (final invalidValue in invalidValues) {
      expect(invalidValue, throwsFormatException);
    }
  });

  test('v3 附件响应拒绝未知字段、身份串线和非规范 Base64URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await requests.cancel();
      await server.close(force: true);
    });
    final createRequest = CloudSyncAttachmentCreateUploadRequest(
      mutationId: _mutationId1,
      attachmentId: _attachmentId,
      chunkKeyEpoch: 7,
      manifestKeyEpoch: 7,
      manifestRevision: 1,
      chunkCount: 1,
      totalCiphertextBytes: 3,
    );
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: 7,
      manifestKeyEpoch: 7,
      manifestRevision: 1,
    );
    final invalidResponse = throwsA(
      isA<CloudSyncException>()
          .having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.invalidResponse,
          )
          .having((error) => error.retryable, 'retryable', isFalse),
    );
    Map<String, Object?> validUploadData() => <String, Object?>{
      'attachmentId': _attachmentId,
      'uploadId': _uploadId,
      'chunkKeyEpoch': 7,
      'manifestKeyEpoch': 7,
      'manifestRevision': 1,
      'chunkCount': 1,
      'totalCiphertextBytes': 3,
      'status': 'open',
      'createdAt': '2026-07-29T00:00:00.000Z',
    };
    Future<void> expectInvalidCreate(Map<String, Object?> response) async {
      final future = client.createAttachmentUpload(
        token: _fullToken,
        request: createRequest,
      );
      final request = await _nextAttachmentRequest(requests);
      await utf8.decoder.bind(request).join();
      await _writeJsonResponse(request, response);
      await expectLater(future, invalidResponse);
    }

    await expectInvalidCreate(<String, Object?>{
      'data': validUploadData(),
      'trace': 'unknown',
    });
    await expectInvalidCreate(<String, Object?>{
      'data': <String, Object?>{...validUploadData(), 'filename': '不得进入服务端'},
    });
    await expectInvalidCreate(<String, Object?>{
      'data': <String, Object?>{
        ...validUploadData(),
        'attachmentId': _recordId1,
      },
    });
    await expectInvalidCreate(<String, Object?>{
      'data': <String, Object?>{
        ...validUploadData(),
        'chunkKeyEpoch': 6,
        'manifestKeyEpoch': 7,
        'manifestRevision': 2,
      },
    });
    await expectInvalidCreate(<String, Object?>{
      'data': <String, Object?>{...validUploadData(), 'manifestRevision': 2},
    });
    final legacyUploadData = validUploadData()
      ..remove('chunkKeyEpoch')
      ..remove('manifestKeyEpoch')
      ..remove('manifestRevision')
      ..['keyEpoch'] = 7;
    await expectInvalidCreate(<String, Object?>{'data': legacyUploadData});

    final manifestFuture = client.getAttachmentManifest(
      token: _fullToken,
      identity: identity,
    );
    final manifestRequest = await _nextAttachmentRequest(requests);
    await utf8.decoder.bind(manifestRequest).join();
    await _writeJsonResponse(manifestRequest, <String, Object?>{
      'data': <String, Object?>{
        'dataRekeyPhase': 'ready',
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 7,
        'manifestKeyEpoch': 7,
        'manifestRevision': 1,
        'chunkCount': 1,
        'totalCiphertextBytes': 3,
        'manifestCiphertext': 'AQ',
        'manifestCiphertextBytes': 1,
        'chunks': <Object?>[
          <String, Object?>{
            'chunkIndex': 0,
            'ciphertextBytes': 3,
            'hash': '不得进入服务端',
          },
        ],
        'committedAt': '2026-07-29T00:01:00.000Z',
      },
    });
    await expectLater(manifestFuture, invalidResponse);

    final driftedManifestFuture = client.getAttachmentManifest(
      token: _fullToken,
      identity: identity,
    );
    final driftedManifestRequest = await _nextAttachmentRequest(requests);
    await utf8.decoder.bind(driftedManifestRequest).join();
    await _writeJsonResponse(driftedManifestRequest, <String, Object?>{
      'data': <String, Object?>{
        'dataRekeyPhase': 'ready',
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 6,
        'manifestKeyEpoch': 7,
        'manifestRevision': 2,
        'chunkCount': 1,
        'totalCiphertextBytes': 3,
        'manifestCiphertext': 'AQ',
        'manifestCiphertextBytes': 1,
        'chunks': <Object?>[
          <String, Object?>{'chunkIndex': 0, 'ciphertextBytes': 3},
        ],
        'committedAt': '2026-07-29T00:01:00.000Z',
      },
    });
    await expectLater(driftedManifestFuture, invalidResponse);

    final chunkFuture = client.getAttachmentChunk(
      token: _fullToken,
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: 0,
      ),
    );
    final chunkRequest = await _nextAttachmentRequest(requests);
    await utf8.decoder.bind(chunkRequest).join();
    await _writeJsonResponse(chunkRequest, <String, Object?>{
      'data': <String, Object?>{
        'dataRekeyPhase': 'ready',
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 7,
        'chunkIndex': 0,
        'ciphertext': 'AQI=',
        'ciphertextBytes': 2,
      },
    });
    await expectLater(chunkFuture, invalidResponse);

    final driftedChunkFuture = client.getAttachmentChunk(
      token: _fullToken,
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: 0,
      ),
    );
    final driftedChunkRequest = await _nextAttachmentRequest(requests);
    await utf8.decoder.bind(driftedChunkRequest).join();
    await _writeJsonResponse(driftedChunkRequest, <String, Object?>{
      'data': <String, Object?>{
        'dataRekeyPhase': 'ready',
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkKeyEpoch': 6,
        'chunkIndex': 0,
        'ciphertext': 'AQID',
        'ciphertextBytes': 3,
      },
    });
    await expectLater(driftedChunkFuture, invalidResponse);
  });

  test('v3 附件错误响应保留冲突代码与请求标识', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });
    final deleteFuture = client.deleteAttachment(
      token: _fullToken,
      request: CloudSyncAttachmentDeleteRequest(
        mutationId: _mutationId1,
        identity: CloudSyncAttachmentIdentity(
          attachmentId: _attachmentId,
          uploadId: _uploadId,
          chunkKeyEpoch: 7,
          manifestKeyEpoch: 7,
          manifestRevision: 1,
        ),
      ),
    );
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    await _writeJsonResponse(request, <String, Object?>{
      'error': <String, Object?>{
        'code': 'ATTACHMENT_MUTATION_CONFLICT',
        'message': 'conflict',
        'retryable': false,
      },
      'requestId': 'attachment-request-1',
    }, statusCode: HttpStatus.conflict);

    await expectLater(
      deleteFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.conflict,
            )
            .having((error) => error.statusCode, 'statusCode', 409)
            .having(
              (error) => error.serverCode,
              'serverCode',
              'ATTACHMENT_MUTATION_CONFLICT',
            )
            .having(
              (error) => error.requestId,
              'requestId',
              'attachment-request-1',
            )
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('v3 协议版本错误保留服务端错误码与请求标识', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges();
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    request.response
      ..statusCode = 426
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{
            'code': 'SYNC_PROTOCOL_VERSION_UNSUPPORTED',
            'message': 'unsupported protocol',
            'retryable': false,
          },
          'requestId': 'request-1',
        }),
      );
    await request.response.close();

    await expectLater(
      pullFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having((error) => error.statusCode, 'statusCode', 426)
            .having(
              (error) => error.serverCode,
              'serverCode',
              'SYNC_PROTOCOL_VERSION_UNSUPPORTED',
            )
            .having((error) => error.requestId, 'requestId', 'request-1')
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('E2EE 附件密码会话隔离清单与分块密钥并在关闭后失败关闭', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[1, 2, 3]),
      openCoordinator: false,
    );
    addTearDown(fixture.close);
    final session = await fixture.openCryptoSession();
    final sealedManifest = await session.sealManifest(
      descriptor: fixture.descriptor,
      uploadId: _uploadId,
      manifestRevision: 1,
    );
    final openedManifest = await session.openManifest(
      attachmentId: fixture.descriptor.attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: fixture.descriptor.chunkKeyEpoch,
      manifestKeyEpoch: fixture.descriptor.chunkKeyEpoch,
      manifestRevision: 1,
      ciphertext: sealedManifest.ciphertext,
    );
    final ciphertext = await session.sealChunk(
      descriptor: fixture.descriptor,
      uploadId: _uploadId,
      chunkIndex: 0,
      plaintext: fixture.plaintext,
    );
    final opened = await session.openChunk(
      manifest: openedManifest,
      chunkIndex: 0,
      ciphertext: ciphertext,
    );

    expect(openedManifest.attachmentId, fixture.descriptor.attachmentId);
    expect(openedManifest.contentSha256, fixture.descriptor.contentSha256);
    expect(opened, fixture.plaintext);
    await expectLater(
      session.openManifest(
        attachmentId: fixture.descriptor.attachmentId,
        uploadId: _uploadId,
        chunkKeyEpoch: fixture.descriptor.chunkKeyEpoch,
        manifestKeyEpoch: fixture.descriptor.chunkKeyEpoch + 1,
        manifestRevision: 2,
        ciphertext: sealedManifest.ciphertext,
      ),
      throwsFormatException,
    );
    final inFlight = session.sealChunk(
      descriptor: fixture.descriptor,
      uploadId: _uploadId,
      chunkIndex: 0,
      plaintext: fixture.plaintext,
    );
    final closing = session.close();
    expect(await inFlight, isNotEmpty);
    await closing;
    await session.close();
    await expectLater(
      session.sealManifest(
        descriptor: fixture.descriptor,
        uploadId: _uploadId,
        manifestRevision: 1,
      ),
      throwsStateError,
    );
  });

  test('E2EE 附件清单重包推进清单代次且旧分块无需重传仍可解密', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[8, 9, 10]),
      openCoordinator: false,
      includePreviousKeyEpoch: true,
      currentKeyEpoch: 8,
      previousKeyEpoch: 6,
    );
    addTearDown(fixture.close);
    const secureCore = KelivoSecureCore();
    final userId = _rawUuid(fixture.session.userId);

    final dataKeyLease = await E2eeAccountKeyLease.open(
      session: fixture.session,
      deviceStateStore: fixture.deviceStateStore,
      secureCore: secureCore,
    );
    final dataKeyArk = dataKeyLease.takeAccountRootKeyOwnership();
    final generated = await secureCore.generateAttachmentDataKey();
    final attachmentId = _uuidStringForTest(generated.attachmentId);
    late final E2eeAttachmentDescriptor sourceDescriptor;
    late final Uint8List oldChunkCiphertext;
    Uint8List? sourceWrappedDataKey;
    try {
      sourceWrappedDataKey = await secureCore.wrapAttachmentDataKey(
        dataKeyArk,
        generated.key,
        context: KelivoAttachmentContext(
          userId: userId,
          attachmentId: generated.attachmentId,
          keyEpoch: 6,
        ),
      );
      final layout = KelivoAttachmentLayout(
        totalPlaintextBytes: fixture.plaintext.length,
      );
      sourceDescriptor = E2eeAttachmentDescriptor(
        attachmentId: attachmentId,
        chunkKeyEpoch: 1,
        kind: E2eeAttachmentKind.file,
        totalPlaintextBytes: fixture.plaintext.length,
        contentSha256: Uint8List.fromList(
          sha256.convert(fixture.plaintext).bytes,
        ),
        wrappedDataKey: sourceWrappedDataKey,
        chunkCiphertextBytes: <int>[
          fixture.plaintext.length +
              KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
        ],
        displayName: 'legacy.bin',
        mediaType: 'application/octet-stream',
      );
      oldChunkCiphertext = await secureCore.sealAttachmentChunk(
        generated.key,
        uploadContext: KelivoAttachmentUploadContext(
          attachment: KelivoAttachmentContext(
            userId: userId,
            attachmentId: generated.attachmentId,
            keyEpoch: 1,
          ),
          uploadId: _rawUuid(_uploadId),
        ),
        layout: layout,
        chunkIndex: 0,
        plaintext: fixture.plaintext,
      );
    } finally {
      sourceWrappedDataKey?.fillRange(0, sourceWrappedDataKey.length, 0);
      await secureCore.closeAttachmentDataKey(generated.key);
      await secureCore.closeAccountRootKey(dataKeyArk);
      await dataKeyLease.close();
    }

    final sourceManifestLease = await E2eeAccountKeyLease.open(
      session: fixture.session,
      deviceStateStore: fixture.deviceStateStore,
      secureCore: secureCore,
    );
    final sourceManifestArk = sourceManifestLease.takeAccountRootKeyOwnership();
    final sourceManifestCipher = E2eeAttachmentManifestCipher.takeOwnership(
      E2eeAccountRecordCipher.takeOwnership(
        secureCore: secureCore,
        accountRootKey: sourceManifestArk,
        userId: fixture.session.userId,
        currentKeyEpoch: 6,
      ),
    );
    late final E2eeSealedAttachmentManifest sourceSealed;
    try {
      sourceSealed = await sourceManifestCipher.seal(
        E2eeAttachmentManifest.fromDescriptor(
          descriptor: sourceDescriptor,
          uploadId: _uploadId,
          manifestKeyEpoch: 6,
          manifestRevision: 6,
        ),
      );
    } finally {
      await sourceManifestCipher.close();
      await sourceManifestLease.close();
    }

    final session = await fixture.openCryptoSession();
    addTearDown(session.close);
    final sourceOpened = await session.openManifest(
      attachmentId: attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: 1,
      manifestKeyEpoch: 6,
      manifestRevision: 6,
      ciphertext: sourceSealed.ciphertext,
    );
    await expectLater(
      session.rewrapManifest(source: sourceOpened, targetManifestRevision: 7),
      throwsFormatException,
    );
    await expectLater(
      session.rewrapManifest(source: sourceOpened, targetManifestRevision: 6),
      throwsFormatException,
    );
    await expectLater(
      session.rewrapManifest(
        source: sourceOpened,
        targetManifestRevision: 0x100000000,
      ),
      throwsFormatException,
    );
    final targetSealed = await session.rewrapManifest(
      source: sourceOpened,
      targetManifestRevision: 8,
    );
    expect(targetSealed.chunkKeyEpoch, 1);
    expect(targetSealed.manifestKeyEpoch, 8);
    expect(targetSealed.manifestRevision, 8);

    final targetOpened = await session.openManifest(
      attachmentId: attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: 1,
      manifestKeyEpoch: 8,
      manifestRevision: 8,
      ciphertext: targetSealed.ciphertext,
    );
    expect(
      targetOpened.wrappedDataKey,
      isNot(orderedEquals(sourceOpened.wrappedDataKey)),
    );

    final verificationLease = await E2eeAccountKeyLease.open(
      session: fixture.session,
      deviceStateStore: fixture.deviceStateStore,
      secureCore: secureCore,
    );
    final verificationArk = verificationLease.takeAccountRootKeyOwnership();
    KelivoAttachmentDataKeyHandle? unwrapped;
    try {
      unwrapped = await secureCore.unwrapAttachmentDataKey(
        verificationArk,
        context: KelivoAttachmentContext(
          userId: userId,
          attachmentId: generated.attachmentId,
          keyEpoch: 8,
        ),
        wrappedKey: targetOpened.wrappedDataKey,
      );
    } finally {
      if (unwrapped != null) {
        await secureCore.closeAttachmentDataKey(unwrapped);
      }
      await secureCore.closeAccountRootKey(verificationArk);
      await verificationLease.close();
    }

    expect(
      await session.openChunk(
        manifest: targetOpened,
        chunkIndex: 0,
        ciphertext: oldChunkCiphertext,
      ),
      fixture.plaintext,
    );
  });

  test('E2EE 附件清单拒绝旧 v1 明文帧', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[1, 3, 5]),
      openCoordinator: false,
    );
    addTearDown(fixture.close);
    const secureCore = KelivoSecureCore();
    final lease = await E2eeAccountKeyLease.open(
      session: fixture.session,
      deviceStateStore: fixture.deviceStateStore,
      secureCore: secureCore,
    );
    final ark = lease.takeAccountRootKeyOwnership();
    final recordCipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: secureCore,
      accountRootKey: ark,
      userId: fixture.session.userId,
      currentKeyEpoch: fixture.session.keyEpoch,
    );
    late final E2eeSealedAccountRecordEnvelope legacyRecord;
    try {
      legacyRecord = await recordCipher.seal(
        entityKey: SyncEntityKey(
          entityType: e2eeAttachmentManifestEntityType,
          entityId: fixture.descriptor.attachmentId,
        ),
        payload: _encodeLegacyAttachmentManifestV1(
          descriptor: fixture.descriptor,
          uploadId: _uploadId,
        ),
      );
    } finally {
      await recordCipher.close();
      await lease.close();
    }

    final session = await fixture.openCryptoSession();
    addTearDown(session.close);
    await expectLater(
      session.openManifest(
        attachmentId: fixture.descriptor.attachmentId,
        uploadId: _uploadId,
        chunkKeyEpoch: fixture.descriptor.chunkKeyEpoch,
        manifestKeyEpoch: fixture.descriptor.chunkKeyEpoch,
        manifestRevision: 1,
        ciphertext: legacyRecord.ciphertext,
      ),
      throwsFormatException,
    );
  });

  test('E2EE 附件上传协调器完成单块并提交认证清单', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[5, 6, 7]),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(10), 3);
    final state = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(state!.phase, E2eeAttachmentUploadPhase.committed);
    expect(fixture.transport.createRequests, hasLength(1));
    expect(fixture.transport.putAttempts, hasLength(1));
    expect(fixture.transport.commitRequests, hasLength(1));
    expect(fixture.transport.createRequests.single.mutationId, _mutationId1);
    expect(
      fixture.transport.createRequests.single.chunkKeyEpoch,
      fixture.descriptor.chunkKeyEpoch,
    );
    expect(
      fixture.transport.createRequests.single.manifestKeyEpoch,
      fixture.descriptor.chunkKeyEpoch,
    );
    expect(fixture.transport.createRequests.single.manifestRevision, 1);
    expect(fixture.transport.commitRequests.single.mutationId, _mutationId2);

    final verifier = await fixture.openCryptoSession();
    addTearDown(verifier.close);
    final commit = fixture.transport.commitRequests.single;
    final manifest = await verifier.openManifest(
      attachmentId: fixture.descriptor.attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: fixture.descriptor.chunkKeyEpoch,
      manifestKeyEpoch: fixture.descriptor.chunkKeyEpoch,
      manifestRevision: 1,
      ciphertext: commit.manifestCiphertext,
    );
    final plaintext = await verifier.openChunk(
      manifest: manifest,
      chunkIndex: 0,
      ciphertext: fixture.transport.putAttempts.single.ciphertext,
    );
    expect(manifest.contentSha256, fixture.descriptor.contentSha256);
    expect(plaintext, fixture.plaintext);
  });

  test('E2EE 附件上传协调器按布局完成多块且不拼接明文缓冲', () async {
    final plaintext = Uint8List.fromList(<int>[
      ...List<int>.filled(KelivoAttachmentLimits.chunkPlaintextBytes, 0x31),
      0x32,
      0x33,
      0x34,
    ]);
    final fixture = await _AttachmentUploadFixture.create(plaintext: plaintext);
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(10), 4);
    expect(fixture.transport.putAttempts, hasLength(2));
    expect(fixture.fileStore.verifiedContentOpens, 1);
    expect(fixture.fileStore.verifiedChunkReads, 2);
    expect(fixture.fileStore.unverifiedRangeReads, 0);
    final verifier = await fixture.openCryptoSession();
    addTearDown(verifier.close);
    final commit = fixture.transport.commitRequests.single;
    final manifest = await verifier.openManifest(
      attachmentId: fixture.descriptor.attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: fixture.descriptor.chunkKeyEpoch,
      manifestKeyEpoch: fixture.descriptor.chunkKeyEpoch,
      manifestRevision: 1,
      ciphertext: commit.manifestCiphertext,
    );
    final rebuilt = BytesBuilder(copy: true);
    for (final attempt in fixture.transport.putAttempts) {
      rebuilt.add(
        await verifier.openChunk(
          manifest: manifest,
          chunkIndex: attempt.chunkIndex,
          ciphertext: attempt.ciphertext,
        ),
      );
    }
    expect(rebuilt.takeBytes(), plaintext);
  });

  test('E2EE 附件上传协调器将零字节内容编码为一个认证空块', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List(0),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(10), 3);
    expect(fixture.transport.putAttempts, hasLength(1));
    expect(
      fixture.transport.putAttempts.single.ciphertext,
      hasLength(KelivoAttachmentLimits.chunkEnvelopeOverheadBytes),
    );
    final verifier = await fixture.openCryptoSession();
    addTearDown(verifier.close);
    final commit = fixture.transport.commitRequests.single;
    final manifest = await verifier.openManifest(
      attachmentId: fixture.descriptor.attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: fixture.descriptor.chunkKeyEpoch,
      manifestKeyEpoch: fixture.descriptor.chunkKeyEpoch,
      manifestRevision: 1,
      ciphertext: commit.manifestCiphertext,
    );
    expect(
      await verifier.openChunk(
        manifest: manifest,
        chunkIndex: 0,
        ciphertext: fixture.transport.putAttempts.single.ciphertext,
      ),
      isEmpty,
    );
  });

  test('E2EE 附件上传协调器严格服从远端步数预算', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[
        ...List<int>.filled(KelivoAttachmentLimits.chunkPlaintextBytes, 0x41),
        0x42,
      ]),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(0), 0);
    expect(fixture.transport.remoteCalls, 0);
    await expectLater(fixture.coordinator.advance(-1), throwsFormatException);
    for (var expectedCalls = 1; expectedCalls <= 4; expectedCalls++) {
      expect(await fixture.coordinator.advance(1), 1);
      expect(fixture.transport.remoteCalls, expectedCalls);
    }
    expect(
      (await fixture.commands.readByAttachmentId(
        fixture.descriptor.attachmentId,
      ))!.phase,
      E2eeAttachmentUploadPhase.committed,
    );
    expect(await fixture.coordinator.advance(1), 0);
  });

  test('E2EE 附件上传协调器将网络与密文字节计入单次执行预算', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[1, 2, 3, 4]),
    );
    addTearDown(fixture.close);
    final exhausted = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 4,
      maximumAttachmentBytes: 0,
      maximumDuration: const Duration(seconds: 5),
      abortInFlightNetwork: () {},
    );
    addTearDown(exhausted.dispose);

    await expectLater(
      fixture.coordinator.advance(4, executionBudget: exhausted),
      throwsA(
        isA<E2eeSyncBudgetExhausted>().having(
          (error) => error.reason,
          'reason',
          E2eeSyncBudgetExhaustion.attachmentBytes,
        ),
      ),
    );
    expect(fixture.transport.createRequests, hasLength(1));
    expect(fixture.transport.putAttempts, isEmpty);
    final pending = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(pending!.phase, E2eeAttachmentUploadPhase.uploading);
    expect(pending.pendingChunk, isNotNull);

    final resumed = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 3,
      maximumAttachmentBytes: 2 * 1024 * 1024,
      maximumDuration: const Duration(seconds: 5),
      abortInFlightNetwork: () {},
    );
    addTearDown(resumed.dispose);
    expect(await fixture.coordinator.advance(3, executionBudget: resumed), 2);
    expect(resumed.networkStepsConsumed, 2);
    expect(
      resumed.attachmentBytesConsumed,
      fixture.transport.putAttempts.single.ciphertext.length +
          fixture.transport.commitRequests.single.manifestCiphertext.length,
    );
  });

  test('E2EE 附件上传协调器在源文件认证边界响应取消且不固化失败', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(List<int>.filled(128 * 1024, 0x35)),
    );
    addTearDown(fixture.close);
    final cancellation = _AttachmentCancellationSignal();
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 4,
      maximumAttachmentBytes: 2 * 1024 * 1024,
      maximumDuration: const Duration(seconds: 5),
      abortInFlightNetwork: () {},
      cancellationSignal: cancellation,
    );
    addTearDown(budget.dispose);
    fixture.fileStore.beforeOpenVerifiedContent = cancellation.cancel;

    await expectLater(
      fixture.coordinator.advance(4, executionBudget: budget),
      throwsA(isA<E2eeSyncExecutionCancelled>()),
    );
    expect(fixture.fileStore.verifiedContentOpens, 0);
    expect(fixture.transport.remoteCalls, 0);
    final released = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(released!.terminalFailureKind, isNull);
  });

  test('E2EE 附件上传协调器在源文件认证边界保留截止异常', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(List<int>.filled(128 * 1024, 0x39)),
    );
    addTearDown(fixture.close);
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 4,
      maximumAttachmentBytes: 2 * 1024 * 1024,
      maximumDuration: const Duration(milliseconds: 5),
      abortInFlightNetwork: () {},
    );
    addTearDown(budget.dispose);
    fixture.fileStore.beforeOpenVerifiedContent = () {
      sleep(const Duration(milliseconds: 20));
    };

    await expectLater(
      fixture.coordinator.advance(4, executionBudget: budget),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );
    expect(fixture.fileStore.verifiedContentOpens, 0);
    expect(fixture.transport.remoteCalls, 0);
    final released = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(released!.terminalFailureKind, isNull);
  });

  test('E2EE 附件上传协调器在分块读取边界响应取消且不创建 staging', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(List<int>.filled(128 * 1024, 0x36)),
    );
    addTearDown(fixture.close);
    expect(await fixture.coordinator.advance(1), 1);

    final cancellation = _AttachmentCancellationSignal();
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 3,
      maximumAttachmentBytes: 2 * 1024 * 1024,
      maximumDuration: const Duration(seconds: 5),
      abortInFlightNetwork: () {},
      cancellationSignal: cancellation,
    );
    addTearDown(budget.dispose);
    fixture.fileStore.beforeVerifiedChunkRead = cancellation.cancel;

    await expectLater(
      fixture.coordinator.advance(3, executionBudget: budget),
      throwsA(isA<E2eeSyncExecutionCancelled>()),
    );
    expect(fixture.transport.putAttempts, isEmpty);
    final released = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(released!.pendingChunk, isNull);
    expect(released.terminalFailureKind, isNull);
  });

  test('E2EE 附件上传协调器在 staging 写入边界响应取消且不转移所有权', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(List<int>.filled(128 * 1024, 0x37)),
    );
    addTearDown(fixture.close);
    expect(await fixture.coordinator.advance(1), 1);

    final cancellation = _AttachmentCancellationSignal();
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 3,
      maximumAttachmentBytes: 2 * 1024 * 1024,
      maximumDuration: const Duration(seconds: 5),
      abortInFlightNetwork: () {},
      cancellationSignal: cancellation,
    );
    addTearDown(budget.dispose);
    fixture.fileStore.beforePublish = cancellation.cancel;

    await expectLater(
      fixture.coordinator.advance(3, executionBudget: budget),
      throwsA(isA<E2eeSyncExecutionCancelled>()),
    );
    expect(fixture.transport.putAttempts, isEmpty);
    final released = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(released!.pendingChunk, isNull);
    expect(released.terminalFailureKind, isNull);
  });

  test('E2EE 附件上传协调器在 pending 密文读取边界响应取消并保留断点', () async {
    final transport = _AttachmentUploadTransport(
      retryablePutFailuresRemaining: 1,
    );
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(List<int>.filled(128 * 1024, 0x38)),
      transport: transport,
    );
    addTearDown(fixture.close);
    expect(await fixture.coordinator.advance(2), 2);
    final pending = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(pending!.pendingChunk, isNotNull);
    final completedReadsBeforeCancellation =
        fixture.fileStore.completedVerifiedReads;
    fixture.clock.value = pending.nextAttemptAt;

    final cancellation = _AttachmentCancellationSignal();
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 2,
      maximumAttachmentBytes: 2 * 1024 * 1024,
      maximumDuration: const Duration(seconds: 5),
      abortInFlightNetwork: () {},
      cancellationSignal: cancellation,
    );
    addTearDown(budget.dispose);
    fixture.fileStore.beforeReadVerified = cancellation.cancel;

    await expectLater(
      fixture.coordinator.advance(2, executionBudget: budget),
      throwsA(isA<E2eeSyncExecutionCancelled>()),
    );
    expect(
      fixture.fileStore.completedVerifiedReads,
      completedReadsBeforeCancellation,
    );
    expect(transport.putAttempts, hasLength(1));
    final retained = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(retained!.pendingChunk, isNotNull);
    expect(retained.terminalFailureKind, isNull);
  });

  test('E2EE 附件上传协调器在源认证耗尽租约后重新 claim 才发起远端请求', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[5, 6]),
    );
    addTearDown(fixture.close);

    fixture.fileStore.beforeOpenVerifiedContent = () {
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
    };
    expect(await fixture.coordinator.advance(1), 1);
    final released = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(released!.attemptCount, 2);
    expect(fixture.transport.createRequests, hasLength(1));
  });

  test('E2EE 附件上传协调器清理租约过期前未被数据库接管的 staging', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[6, 7]),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(1), 1);
    E2eeAttachmentStoredFile? abandoned;
    fixture.fileStore.afterPublish = (stored) {
      if (abandoned != null) return;
      abandoned = stored;
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
    };
    expect(await fixture.coordinator.advance(1), 1);
    expect(abandoned, isNotNull);
    await expectLater(
      fixture.fileStore.readVerified(abandoned!),
      throwsA(isA<FileSystemException>()),
    );
    expect(fixture.transport.putAttempts, hasLength(1));
  });

  test('E2EE 附件上传协调器网络重试跨重启逐字节重放 pending 密文', () async {
    final transport = _AttachmentUploadTransport(
      retryablePutFailuresRemaining: 1,
    );
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[7, 8, 9]),
      transport: transport,
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(2), 2);
    final deferred = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(deferred!.phase, E2eeAttachmentUploadPhase.uploading);
    expect(deferred.pendingChunk, isNotNull);
    expect(deferred.consecutiveFailureCount, 1);
    expect(
      deferred.nextAttemptAt,
      fixture.clock.value.add(const Duration(seconds: 1)),
    );
    final first = transport.putAttempts.single;

    await fixture.restartCoordinator();
    fixture.clock.value = deferred.nextAttemptAt.subtract(
      const Duration(microseconds: 1),
    );
    expect(await fixture.coordinator.advance(2), 0);
    expect(transport.putAttempts, hasLength(1));
    fixture.clock.value = deferred.nextAttemptAt;
    expect(await fixture.coordinator.advance(2), 2);
    expect(transport.putAttempts, hasLength(2));
    final replay = transport.putAttempts.last;
    expect(replay.mutationId, first.mutationId);
    expect(replay.ciphertext, first.ciphertext);
    expect(
      (await fixture.commands.readByAttachmentId(
        fixture.descriptor.attachmentId,
      ))!.phase,
      E2eeAttachmentUploadPhase.committed,
    );
  });

  test('E2EE 附件上传协调器在途取消仅释放 create chunk commit 租约', () async {
    for (final stage in <String>['create', 'chunk', 'commit']) {
      final transport = _AttachmentUploadTransport();
      final fixture = await _AttachmentUploadFixture.create(
        plaintext: Uint8List.fromList(<int>[8, 9, 10]),
        transport: transport,
      );
      try {
        switch (stage) {
          case 'chunk':
            expect(await fixture.coordinator.advance(1), 1);
          case 'commit':
            expect(await fixture.coordinator.advance(2), 2);
        }

        final started = Completer<void>();
        final release = Completer<void>();
        Future<void> blockInFlight() {
          started.complete();
          return release.future;
        }

        const cancellation = CloudSyncException(
          kind: CloudSyncFailureKind.cancelled,
          retryable: false,
        );
        switch (stage) {
          case 'create':
            transport
              ..beforeCreate = blockInFlight
              ..createFailure = cancellation;
          case 'chunk':
            transport
              ..beforePut = blockInFlight
              ..putFailure = cancellation;
          case 'commit':
            transport
              ..beforeCommit = blockInFlight
              ..commitFailure = cancellation;
        }

        final advance = fixture.coordinator.advance(1);
        await started.future;
        release.complete();
        await expectLater(
          advance,
          throwsA(
            isA<CloudSyncException>().having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.cancelled,
            ),
          ),
          reason: stage,
        );
        final released = await fixture.commands.readByAttachmentId(
          fixture.descriptor.attachmentId,
        );
        expect(released!.terminalFailureKind, isNull, reason: stage);

        transport
          ..beforeCreate = null
          ..beforePut = null
          ..beforeCommit = null
          ..createFailure = null
          ..putFailure = null
          ..commitFailure = null;
        expect(await fixture.coordinator.advance(4), greaterThan(0));
        expect(
          (await fixture.commands.readByAttachmentId(
            fixture.descriptor.attachmentId,
          ))!.phase,
          E2eeAttachmentUploadPhase.committed,
          reason: stage,
        );
      } finally {
        await fixture.close();
      }
    }
  });

  test('E2EE 附件上传协调器保留终止认证错误供上层退役会话', () async {
    for (final kind in <CloudSyncFailureKind>[
      CloudSyncFailureKind.unauthenticated,
      CloudSyncFailureKind.forbidden,
    ]) {
      final transport = _AttachmentUploadTransport(
        createFailure: CloudSyncException(kind: kind, retryable: false),
      );
      final fixture = await _AttachmentUploadFixture.create(
        plaintext: Uint8List.fromList(<int>[9, 10, 11]),
        transport: transport,
      );
      try {
        await expectLater(
          fixture.coordinator.advance(1),
          throwsA(
            isA<CloudSyncException>().having(
              (error) => error.kind,
              'kind',
              kind,
            ),
          ),
          reason: kind.name,
        );
        final released = await fixture.commands.readByAttachmentId(
          fixture.descriptor.attachmentId,
        );
        expect(released!.terminalFailureKind, isNull, reason: kind.name);
        transport.createFailure = null;
        expect(await fixture.coordinator.advance(3), 3, reason: kind.name);
        expect(
          (await fixture.commands.readByAttachmentId(
            fixture.descriptor.attachmentId,
          ))!.phase,
          E2eeAttachmentUploadPhase.committed,
          reason: kind.name,
        );
      } finally {
        await fixture.close();
      }
    }
  });

  test('E2EE 附件上传协调器将不可重试响应固化为终止状态', () async {
    final transport = _AttachmentUploadTransport(
      permanentPutFailure: const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      ),
    );
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[10, 11]),
      transport: transport,
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(10), 2);
    final terminal = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(terminal!.terminalFailureKind, 'remote-validation');
    expect(terminal.pendingChunk, isNotNull);
    fixture.clock.value = fixture.clock.value.add(const Duration(days: 1));
    expect(await fixture.coordinator.advance(10), 0);
    expect(transport.putAttempts, hasLength(1));
  });

  test('E2EE 附件上传协调器仍将远端身份错配响应固化为终止状态', () async {
    final transport = _AttachmentUploadTransport(
      returnInvalidCreateResponse: true,
    );
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[11, 12]),
      transport: transport,
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(1), 1);
    final terminal = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(terminal!.terminalFailureKind, 'remote-invalid-response');
    expect(transport.createRequests, hasLength(1));
  });

  test('E2EE 附件上传协调器在任何远端写入前终止源摘要错配', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[12, 13]),
      descriptorContentSha256: _filledBytes(32, 0xee),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(10), 0);
    final terminal = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(terminal!.terminalFailureKind, 'source-integrity-failed');
    expect(fixture.transport.remoteCalls, 0);
  });

  test('E2EE 附件上传协调器对瞬时本地 IO 退避后继续', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[14, 15]),
      transientVerifyFailures: 1,
    );
    addTearDown(fixture.close);

    final firstAttemptAt = fixture.clock.value;
    expect(await fixture.coordinator.advance(10), 0);
    final deferred = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(deferred!.terminalFailureKind, isNull);
    expect(deferred.lastFailureKind, 'local-io');
    expect(deferred.consecutiveFailureCount, 1);
    expect(
      deferred.nextAttemptAt,
      firstAttemptAt.add(const Duration(seconds: 1)),
    );
    fixture.clock.value = deferred.nextAttemptAt;
    expect(await fixture.coordinator.advance(10), 3);
    expect(
      (await fixture.commands.readByAttachmentId(
        fixture.descriptor.attachmentId,
      ))!.phase,
      E2eeAttachmentUploadPhase.committed,
    );
  });

  test('E2EE 附件上传协调器不会因租约同时过期而吞掉未知本地错误', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[15, 16]),
    );
    addTearDown(fixture.close);

    fixture.fileStore.beforeOpenVerifiedContent = () {
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
      throw StateError('unexpected-local-failure');
    };

    await expectLater(
      fixture.coordinator.advance(1),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'unexpected-local-failure',
        ),
      ),
    );
    expect(fixture.transport.remoteCalls, 0);
  });

  test('E2EE 附件上传协调器在远端成功但租约过期后原样重放 mutation', () async {
    final transport = _AttachmentUploadTransport();
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[16, 17]),
      transport: transport,
    );
    addTearDown(fixture.close);

    var expireCreate = true;
    transport.afterCreate = () {
      if (!expireCreate) return;
      expireCreate = false;
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
    };
    expect(await fixture.coordinator.advance(1), 1);
    expect(
      (await fixture.commands.readByAttachmentId(
        fixture.descriptor.attachmentId,
      ))!.phase,
      E2eeAttachmentUploadPhase.createPending,
    );
    expect(await fixture.coordinator.advance(1), 1);
    expect(transport.createRequests, hasLength(2));
    expect(
      transport.createRequests.last.mutationId,
      transport.createRequests.first.mutationId,
    );

    var expirePut = true;
    transport.afterPut = () {
      if (!expirePut) return;
      expirePut = false;
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
    };
    expect(await fixture.coordinator.advance(1), 1);
    final chunkPending = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(chunkPending!.phase, E2eeAttachmentUploadPhase.uploading);
    expect(chunkPending.pendingChunk, isNotNull);
    expect(await fixture.coordinator.advance(1), 1);
    expect(transport.putAttempts, hasLength(2));
    expect(
      transport.putAttempts.last.mutationId,
      transport.putAttempts.first.mutationId,
    );
    expect(
      transport.putAttempts.last.ciphertext,
      transport.putAttempts.first.ciphertext,
    );

    var expireCommit = true;
    transport.afterCommit = () {
      if (!expireCommit) return;
      expireCommit = false;
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
    };
    expect(await fixture.coordinator.advance(1), 1);
    final commitPending = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(commitPending!.phase, E2eeAttachmentUploadPhase.commitPending);
    expect(await fixture.coordinator.advance(1), 1);
    expect(transport.commitRequests, hasLength(2));
    expect(
      transport.commitRequests.last.mutationId,
      transport.commitRequests.first.mutationId,
    );
    expect(
      transport.commitRequests.last.manifestCiphertext,
      transport.commitRequests.first.manifestCiphertext,
    );
    expect(
      (await fixture.commands.readByAttachmentId(
        fixture.descriptor.attachmentId,
      ))!.phase,
      E2eeAttachmentUploadPhase.committed,
    );
  });

  test('E2EE 附件上传协调器拒绝被篡改的 pending 密文', () async {
    final transport = _AttachmentUploadTransport(
      retryablePutFailuresRemaining: 1,
    );
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[18, 19]),
      transport: transport,
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(2), 2);
    final deferred = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    fixture.fileStore.rejectPendingReads = true;
    fixture.clock.value = deferred!.nextAttemptAt;
    expect(await fixture.coordinator.advance(10), 0);
    final terminal = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(
      terminal!.terminalFailureKind,
      'pending-ciphertext-integrity-failed',
    );
    expect(transport.putAttempts, hasLength(1));
  });

  test('E2EE 附件上传协调器将丢失的 pending 密文固化为终止状态', () async {
    final transport = _AttachmentUploadTransport(
      retryablePutFailuresRemaining: 1,
    );
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[20, 21]),
      transport: transport,
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(2), 2);
    final deferred = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    fixture.fileStore
      ..rejectPendingReads = true
      ..reportPendingMissing = true;
    fixture.clock.value = deferred!.nextAttemptAt;
    expect(await fixture.coordinator.advance(10), 0);
    final terminal = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(
      terminal!.terminalFailureKind,
      'pending-ciphertext-integrity-failed',
    );
    expect(transport.putAttempts, hasLength(1));
  });

  test('E2EE 附件上传协调器关闭失败后保留资源并允许重试关闭', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[22, 23]),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(1), 1);
    fixture.fileStore.verifiedContentCloseFailures = 1;
    await expectLater(
      fixture.coordinator.close(),
      throwsA(isA<FileSystemException>()),
    );
    await fixture.coordinator.close();
    await expectLater(
      fixture.coordinator.advance(1),
      throwsA(isA<StateError>()),
    );
  });

  test('E2EE 附件内存文件 adapter 保持完整性合同与 staging 删除边界', () async {
    final store = E2eeAttachmentMemoryFileStore();
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: 7,
      manifestKeyEpoch: 7,
      manifestRevision: 1,
    );
    final location = E2eeAttachmentFileLocation.stagingUploadChunk(
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: 0,
      ),
      mutationId: _mutationId1,
    );
    final ciphertext = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final stored = await store.publish(
      location: location,
      source: Stream<List<int>>.value(ciphertext),
    );

    expect(
      stored.storagePath,
      'memory://kelivo-e2ee-attachments/staging/upload/'
      '$_attachmentId/$_uploadId/7/7/1/0-$_mutationId1.ciphertext',
    );
    expect(await store.readVerified(stored), ciphertext);
    await expectLater(
      store.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: stored.storagePath,
          bytes: cloudSyncMaximumAttachmentChunkCiphertextBytes + 1,
          sha256: stored.sha256,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    final repeated = await store.publish(
      location: location,
      source: Stream<List<int>>.value(ciphertext),
    );
    expect(repeated.storagePath, stored.storagePath);
    await expectLater(
      store.publish(
        location: location,
        source: Stream<List<int>>.value(<int>[9, 9, 9]),
      ),
      throwsA(isA<StateError>()),
    );
    final alternateMutation = await store.publish(
      location: E2eeAttachmentFileLocation.stagingUploadChunk(
        chunk: CloudSyncAttachmentChunkIdentity(
          identity: identity,
          chunkIndex: 0,
        ),
        mutationId: _mutationId2,
      ),
      source: Stream<List<int>>.value(<int>[9, 9, 9]),
    );
    expect(alternateMutation.storagePath, isNot(stored.storagePath));
    await expectLater(
      store.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: stored.storagePath,
          bytes: stored.bytes + 1,
          sha256: stored.sha256,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: stored.storagePath,
          bytes: stored.bytes,
          sha256: _filledBytes(32, 0xff),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.publish(
        location: E2eeAttachmentFileLocation.stagingUploadChunk(
          chunk: CloudSyncAttachmentChunkIdentity(
            identity: identity,
            chunkIndex: 1,
          ),
          mutationId: _mutationId3,
        ),
        source: Stream<List<int>>.value(<int>[256]),
      ),
      throwsA(isA<FormatException>()),
    );

    final content = Uint8List.fromList(<int>[5, 6, 7]);
    final contentDigest = Uint8List.fromList(sha256.convert(content).bytes);
    final contentStored = await store.publish(
      location: E2eeAttachmentFileLocation.content(
        contentSha256: contentDigest,
      ),
      source: Stream<List<int>>.value(content),
    );
    expect(await store.readVerified(contentStored), content);
    expect(
      await store.readContentRange(
        storedFile: contentStored,
        offset: 1,
        length: 2,
      ),
      orderedEquals(<int>[6, 7]),
    );
    final contentReader = await store.openVerifiedContent(
      storedFile: contentStored,
      chunkPlaintextBytes: <int>[1, 2],
    );
    expect(await contentReader.readChunk(1), orderedEquals(<int>[6, 7]));
    await contentReader.close();
    await expectLater(contentReader.readChunk(0), throwsA(isA<StateError>()));
    await store.verifyContent(contentStored);
    await expectLater(
      store.readContentRange(storedFile: contentStored, offset: 2, length: 2),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.publish(
        location: E2eeAttachmentFileLocation.content(
          contentSha256: _filledBytes(32, 0x31),
        ),
        source: Stream<List<int>>.value(content),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.deleteStaging(storagePath: contentStored.storagePath),
      throwsA(isA<StateError>()),
    );

    await store.deleteStaging(storagePath: stored.storagePath);
    await store.deleteStaging(storagePath: stored.storagePath);
    await expectLater(
      store.readVerified(stored),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('E2EE 附件平台文件 adapter 原子发布且拒绝越界与异常实体', () async {
    final root = await Directory.current.createTemp(
      'kelivo-e2ee-attachment-file-store-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final installation = await Directory(
      p.join(root.path, 'installation'),
    ).create();
    final workspace = await Directory(
      p.join(root.path, 'account-workspace'),
    ).create();
    AppDirectories.bindWorkspaceRoot(
      workspace,
      installationRoot: installation,
      accountWorkspace: true,
    );

    final store = E2eeAttachmentPlatformFileStore();
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: 0xffffffff,
      manifestKeyEpoch: 0xffffffff,
      manifestRevision: 1,
    );
    final location = E2eeAttachmentFileLocation.stagingUploadChunk(
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: 999,
      ),
      mutationId: _mutationId1,
    );
    final ciphertext = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
    final stored = await store.publish(
      location: location,
      source: Stream<List<int>>.fromIterable(<List<int>>[
        ciphertext.sublist(0, 2),
        ciphertext.sublist(2),
      ]),
    );
    final ownedRoot = p.join(workspace.path, 'upload', 'e2ee');
    expect(
      p.equals(
        stored.storagePath,
        p.join(
          ownedRoot,
          'staging',
          'upload',
          _attachmentId,
          _uploadId,
          '4294967295',
          '4294967295',
          '1',
          '999-$_mutationId1.ciphertext',
        ),
      ),
      isTrue,
    );
    expect(await store.readVerified(stored), ciphertext);
    expect(
      (await store.publish(
        location: location,
        source: Stream<List<int>>.value(ciphertext),
      )).storagePath,
      stored.storagePath,
    );
    await expectLater(
      store.publish(
        location: location,
        source: Stream<List<int>>.value(<int>[8, 8, 8]),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await File(stored.storagePath).parent
          .list(followLinks: false)
          .where((entity) => p.basename(entity.path).endsWith('.next'))
          .isEmpty,
      isTrue,
    );
    expect(await store.readVerified(stored), ciphertext);

    final interruptedLocation = E2eeAttachmentFileLocation.stagingUploadChunk(
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: 998,
      ),
      mutationId: _mutationId2,
    );
    await expectLater(
      store.publish(
        location: interruptedLocation,
        source: Stream<List<int>>.error(StateError('source-interrupted')),
      ),
      throwsA(isA<StateError>()),
    );
    final stagingDirectory = File(stored.storagePath).parent;
    expect(
      await File(
        p.join(stagingDirectory.path, '998-$_mutationId2.ciphertext'),
      ).exists(),
      isFalse,
    );
    expect(
      await stagingDirectory
          .list(followLinks: false)
          .where((entity) => p.basename(entity.path).endsWith('.next'))
          .isEmpty,
      isTrue,
    );

    final boundedLocation = E2eeAttachmentFileLocation.stagingUploadChunk(
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: 997,
      ),
      mutationId: _mutationId3,
    );
    final boundedCiphertext = Uint8List.fromList(
      List<int>.filled(3 * 64 * 1024, 0x61),
    );
    for (final interruptAt in <int>[3, 8]) {
      var stagingChecks = 0;
      await expectLater(
        store.publish(
          location: boundedLocation,
          source: Stream<List<int>>.value(boundedCiphertext),
          checkCanContinue: () {
            stagingChecks++;
            if (stagingChecks == interruptAt) {
              throw const E2eeSyncDeadlineExceeded();
            }
          },
        ),
        throwsA(isA<E2eeSyncDeadlineExceeded>()),
      );
      expect(stagingChecks, interruptAt);
      expect(
        await File(
          p.join(stagingDirectory.path, '997-$_mutationId3.ciphertext'),
        ).exists(),
        isFalse,
      );
      expect(
        await stagingDirectory
            .list(followLinks: false)
            .where((entity) => p.basename(entity.path).endsWith('.next'))
            .isEmpty,
        isTrue,
      );
    }

    await expectLater(
      store.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: p.join(root.path, 'outside.ciphertext'),
          bytes: 0,
          sha256: Uint8List.fromList(sha256.convert(const <int>[]).bytes),
        ),
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: stored.storagePath,
          bytes: stored.bytes,
          sha256: _filledBytes(32, 0x41),
        ),
      ),
      throwsA(isA<FormatException>()),
    );

    final downloadMarker = File(p.join(ownedRoot, 'staging', 'download'));
    await downloadMarker.writeAsString('not-a-directory', flush: true);
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: identity,
        persistedStoragePath: null,
        confirmedPlaintextBytes: 0,
      ),
      throwsA(isA<StateError>()),
    );
    await downloadMarker.delete();

    final content = Uint8List.fromList(<int>[11, 12, 13]);
    final contentDigest = Uint8List.fromList(sha256.convert(content).bytes);
    final contentStored = await store.publish(
      location: E2eeAttachmentFileLocation.content(
        contentSha256: contentDigest,
      ),
      source: Stream<List<int>>.value(content),
    );
    expect(
      p.equals(
        contentStored.storagePath,
        p.join(
          ownedRoot,
          'content',
          contentDigest
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(),
        ),
      ),
      isTrue,
    );
    expect(await store.readVerified(contentStored), content);
    expect(
      await store.readContentRange(
        storedFile: contentStored,
        offset: 1,
        length: 2,
      ),
      orderedEquals(<int>[12, 13]),
    );
    final contentReader = await store.openVerifiedContent(
      storedFile: contentStored,
      chunkPlaintextBytes: <int>[1, 2],
    );
    expect(await contentReader.readChunk(1), orderedEquals(<int>[12, 13]));
    await contentReader.close();

    final boundedContent = Uint8List.fromList(
      List<int>.filled(3 * 64 * 1024, 0x62),
    );
    final boundedContentDigest = Uint8List.fromList(
      sha256.convert(boundedContent).bytes,
    );
    final boundedContentStored = await store.publish(
      location: E2eeAttachmentFileLocation.content(
        contentSha256: boundedContentDigest,
      ),
      source: Stream<List<int>>.value(boundedContent),
    );
    var verificationChecks = 0;
    await expectLater(
      store.openVerifiedContent(
        storedFile: boundedContentStored,
        chunkPlaintextBytes: <int>[boundedContent.length],
        checkCanContinue: () {
          verificationChecks++;
          if (verificationChecks == 6) {
            throw const E2eeSyncExecutionCancelled();
          }
        },
      ),
      throwsA(isA<E2eeSyncExecutionCancelled>()),
    );
    expect(verificationChecks, 6);
    final renamedBoundedContent = File(
      '${boundedContentStored.storagePath}.moved',
    );
    await File(
      boundedContentStored.storagePath,
    ).rename(renamedBoundedContent.path);
    await renamedBoundedContent.rename(boundedContentStored.storagePath);
    await store.verifyContent(contentStored);
    await expectLater(
      store.readContentRange(storedFile: contentStored, offset: -1, length: 1),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.publish(
        location: E2eeAttachmentFileLocation.content(
          contentSha256: _filledBytes(32, 0x51),
        ),
        source: Stream<List<int>>.value(content),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.deleteStaging(storagePath: contentStored.storagePath),
      throwsA(isA<StateError>()),
    );

    await File(
      contentStored.storagePath,
    ).writeAsBytes(<int>[11, 12, 14], flush: true);
    await expectLater(
      store.verifyContent(contentStored),
      throwsA(isA<FormatException>()),
    );

    await File(stored.storagePath).writeAsBytes(<int>[1, 2, 3], flush: true);
    await expectLater(
      store.readVerified(stored),
      throwsA(isA<FormatException>()),
    );
    await store.deleteStaging(storagePath: stored.storagePath);
    await store.deleteStaging(storagePath: stored.storagePath);
    await expectLater(
      store.readVerified(stored),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('E2EE 附件平台文件 adapter 只清理无引用内容文件并拒绝异常实体', () async {
    final root = await Directory.current.createTemp(
      'kelivo-e2ee-content-reconcile-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final installation = await Directory(
      p.join(root.path, 'installation'),
    ).create();
    final workspace = await Directory(
      p.join(root.path, 'account-workspace'),
    ).create();
    AppDirectories.bindWorkspaceRoot(
      workspace,
      installationRoot: installation,
      accountWorkspace: true,
    );

    final store = E2eeAttachmentPlatformFileStore();
    final retainedBytes = Uint8List.fromList(<int>[1, 2, 3]);
    final retained = await store.publish(
      location: E2eeAttachmentFileLocation.content(
        contentSha256: Uint8List.fromList(sha256.convert(retainedBytes).bytes),
      ),
      source: Stream<List<int>>.value(retainedBytes),
    );
    final orphanedBytes = Uint8List.fromList(<int>[4, 5, 6]);
    final orphaned = await store.publish(
      location: E2eeAttachmentFileLocation.content(
        contentSha256: Uint8List.fromList(sha256.convert(orphanedBytes).bytes),
      ),
      source: Stream<List<int>>.value(orphanedBytes),
    );
    final contentDirectory = File(retained.storagePath).parent;
    final unknown = File(p.join(contentDirectory.path, 'unknown-file'));
    await unknown.writeAsString('leave untouched', flush: true);

    expect(
      await store.reconcileUnreferencedContent(
        isPathDemanded: (path) async => p.equals(path, retained.storagePath),
      ),
      1,
    );
    expect(await File(retained.storagePath).exists(), isTrue);
    expect(await File(orphaned.storagePath).exists(), isFalse);
    expect(await unknown.exists(), isTrue);

    final unsafe = Directory(
      p.join(contentDirectory.path, List<String>.filled(64, 'f').join()),
    );
    await unsafe.create();
    await expectLater(
      store.reconcileUnreferencedContent(isPathDemanded: (_) async => true),
      throwsA(isA<StateError>()),
    );
  });

  test('E2EE 附件内存下载明文 staging 只按持久确认进度恢复并幂等发布', () async {
    final store = E2eeAttachmentMemoryFileStore();
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: 7,
      manifestKeyEpoch: 7,
      manifestRevision: 1,
    );
    final firstChunk = Uint8List.fromList(<int>[1, 2]);
    final secondChunk = Uint8List.fromList(<int>[3, 4, 5]);
    final plaintext = Uint8List.fromList(<int>[...firstChunk, ...secondChunk]);
    final contentDigest = Uint8List.fromList(sha256.convert(plaintext).bytes);
    final resolvedContentPath = await store.resolveContentStoragePath(
      contentDigest,
    );
    expect(
      resolvedContentPath,
      'memory://kelivo-e2ee-attachments/content/'
      '${sha256.convert(plaintext)}',
    );
    await expectLater(
      store.resolveContentStoragePath(Uint8List(31)),
      throwsA(isA<FormatException>()),
    );

    final stagingPath = await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    expect(
      stagingPath,
      'memory://kelivo-e2ee-attachments/staging/download/'
      '$_attachmentId/$_uploadId/7/7/1/plaintext.part',
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: 0,
      plaintext: firstChunk,
    );

    // 文件尾可能先于数据库确认落盘，恢复只能回退到数据库已确认位置。
    expect(
      await store.openDownloadPlaintextStaging(
        identity: identity,
        persistedStoragePath: stagingPath,
        confirmedPlaintextBytes: 0,
      ),
      stagingPath,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: 0,
      plaintext: firstChunk,
    );
    await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: stagingPath,
      confirmedPlaintextBytes: firstChunk.length,
    );
    await expectLater(
      store.appendDownloadPlaintextChunk(
        identity: identity,
        stagingPath: stagingPath,
        expectedOffset: 0,
        plaintext: secondChunk,
      ),
      throwsA(isA<StateError>()),
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: firstChunk.length,
      plaintext: secondChunk,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: plaintext.length,
      plaintext: Uint8List.fromList(<int>[99]),
    );
    await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: stagingPath,
      confirmedPlaintextBytes: plaintext.length,
    );

    final stored = await store.publishDownloadPlaintext(
      identity: identity,
      stagingPath: stagingPath,
      expectedPlaintextBytes: plaintext.length,
      expectedSha256: contentDigest,
    );
    expect(stored.bytes, plaintext.length);
    expect(stored.sha256, contentDigest);
    await store.verifyContent(stored);
    final repeated = await store.publishDownloadPlaintext(
      identity: identity,
      stagingPath: stagingPath,
      expectedPlaintextBytes: plaintext.length,
      expectedSha256: contentDigest,
    );
    expect(repeated.storagePath, stored.storagePath);

    final isolatedIdentity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: 8,
      manifestKeyEpoch: 8,
      manifestRevision: 1,
    );
    expect(
      await store.openDownloadPlaintextStaging(
        identity: isolatedIdentity,
        persistedStoragePath: null,
        confirmedPlaintextBytes: 0,
      ),
      isNot(stagingPath),
    );
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: isolatedIdentity,
        persistedStoragePath:
            'memory://kelivo-e2ee-attachments/staging/download/'
            '$_attachmentId/$_uploadId/8/8/1/plaintext.part',
        confirmedPlaintextBytes: 1,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: identity,
        persistedStoragePath:
            'memory://kelivo-e2ee-attachments/staging/download/'
            '$_attachmentId/$_mutationId1/7/7/1/plaintext.part',
        confirmedPlaintextBytes: 0,
      ),
      throwsA(isA<StateError>()),
    );

    final zeroIdentity = CloudSyncAttachmentIdentity(
      attachmentId: _mutationId1,
      uploadId: _mutationId2,
      chunkKeyEpoch: 9,
      manifestKeyEpoch: 9,
      manifestRevision: 1,
    );
    final zeroStaging = await store.openDownloadPlaintextStaging(
      identity: zeroIdentity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    await store.appendDownloadPlaintextChunk(
      identity: zeroIdentity,
      stagingPath: zeroStaging,
      expectedOffset: 0,
      plaintext: Uint8List(0),
    );
    final emptyDigest = Uint8List.fromList(sha256.convert(const <int>[]).bytes);
    final zeroStored = await store.publishDownloadPlaintext(
      identity: zeroIdentity,
      stagingPath: zeroStaging,
      expectedPlaintextBytes: 0,
      expectedSha256: emptyDigest,
    );
    expect(zeroStored.bytes, 0);
    await store.verifyContent(zeroStored);

    final corruptIdentity = CloudSyncAttachmentIdentity(
      attachmentId: _mutationId2,
      uploadId: _mutationId3,
      chunkKeyEpoch: 10,
      manifestKeyEpoch: 10,
      manifestRevision: 1,
    );
    final corruptStaging = await store.openDownloadPlaintextStaging(
      identity: corruptIdentity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    await store.appendDownloadPlaintextChunk(
      identity: corruptIdentity,
      stagingPath: corruptStaging,
      expectedOffset: 0,
      plaintext: Uint8List.fromList(<int>[8, 8]),
    );
    await expectLater(
      store.publishDownloadPlaintext(
        identity: corruptIdentity,
        stagingPath: corruptStaging,
        expectedPlaintextBytes: 2,
        expectedSha256: Uint8List.fromList(
          sha256.convert(const <int>[8, 9]).bytes,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.publishDownloadPlaintext(
        identity: corruptIdentity,
        stagingPath: corruptStaging,
        expectedPlaintextBytes: 1,
        expectedSha256: emptyDigest,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('E2EE 附件平台下载明文 staging 流式验密并拒绝篡改与异常路径', () async {
    final root = await Directory.current.createTemp(
      'kelivo-e2ee-download-plaintext-store-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final installation = await Directory(
      p.join(root.path, 'installation'),
    ).create();
    final workspace = await Directory(
      p.join(root.path, 'account-workspace'),
    ).create();
    AppDirectories.bindWorkspaceRoot(
      workspace,
      installationRoot: installation,
      accountWorkspace: true,
    );

    final store = E2eeAttachmentPlatformFileStore();
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      chunkKeyEpoch: 0xffffffff,
      manifestKeyEpoch: 0xffffffff,
      manifestRevision: 1,
    );
    final firstChunk = Uint8List.fromList(<int>[11, 12]);
    final secondChunk = Uint8List.fromList(<int>[13, 14, 15]);
    final plaintext = Uint8List.fromList(<int>[...firstChunk, ...secondChunk]);
    final contentDigest = Uint8List.fromList(sha256.convert(plaintext).bytes);
    final resolvedContentPath = await store.resolveContentStoragePath(
      contentDigest,
    );
    expect(
      p.equals(
        resolvedContentPath,
        p.join(
          workspace.path,
          'upload',
          'e2ee',
          'content',
          '${sha256.convert(plaintext)}',
        ),
      ),
      isTrue,
    );
    await expectLater(
      store.resolveContentStoragePath(Uint8List(33)),
      throwsA(isA<FormatException>()),
    );
    final stagingPath = await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    expect(
      p.equals(
        stagingPath,
        p.join(
          workspace.path,
          'upload',
          'e2ee',
          'staging',
          'download',
          _attachmentId,
          _uploadId,
          '4294967295',
          '4294967295',
          '1',
          'plaintext.part',
        ),
      ),
      isTrue,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: 0,
      plaintext: firstChunk,
    );
    await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: stagingPath,
      confirmedPlaintextBytes: firstChunk.length,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: firstChunk.length,
      plaintext: secondChunk,
    );
    final crashTail = await File(stagingPath).open(mode: FileMode.append);
    await crashTail.writeFrom(const <int>[99, 100]);
    await crashTail.flush();
    await crashTail.close();
    await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: stagingPath,
      confirmedPlaintextBytes: plaintext.length,
    );
    expect(await File(stagingPath).length(), plaintext.length);
    await expectLater(
      store.appendDownloadPlaintextChunk(
        identity: identity,
        stagingPath: stagingPath,
        expectedOffset: firstChunk.length,
        plaintext: secondChunk,
      ),
      throwsA(isA<StateError>()),
    );

    final tampered = await File(stagingPath).readAsBytes();
    tampered[1] = 0xff;
    await File(stagingPath).writeAsBytes(tampered, flush: true);
    await expectLater(
      store.publishDownloadPlaintext(
        identity: identity,
        stagingPath: stagingPath,
        expectedPlaintextBytes: plaintext.length,
        expectedSha256: contentDigest,
      ),
      throwsA(isA<FormatException>()),
    );

    await store.deleteStaging(storagePath: stagingPath);
    await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: stagingPath,
      confirmedPlaintextBytes: 0,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: 0,
      plaintext: firstChunk,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: firstChunk.length,
      plaintext: secondChunk,
    );
    final stored = await store.publishDownloadPlaintext(
      identity: identity,
      stagingPath: stagingPath,
      expectedPlaintextBytes: plaintext.length,
      expectedSha256: contentDigest,
    );
    expect(p.equals(stored.storagePath, resolvedContentPath), isTrue);
    expect(await File(stored.storagePath).length(), plaintext.length);
    await store.verifyContent(stored);
    final repeated = await store.publishDownloadPlaintext(
      identity: identity,
      stagingPath: stagingPath,
      expectedPlaintextBytes: plaintext.length,
      expectedSha256: contentDigest,
    );
    expect(repeated.storagePath, stored.storagePath);

    await File(
      stored.storagePath,
    ).writeAsBytes(const <int>[11, 12, 13, 14, 16], flush: true);
    await expectLater(
      store.publishDownloadPlaintext(
        identity: identity,
        stagingPath: stagingPath,
        expectedPlaintextBytes: plaintext.length,
        expectedSha256: contentDigest,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: identity,
        persistedStoragePath: p.join(root.path, 'outside.part'),
        confirmedPlaintextBytes: 0,
      ),
      throwsA(isA<StateError>()),
    );

    final unsafeIdentity = CloudSyncAttachmentIdentity(
      attachmentId: _mutationId1,
      uploadId: _mutationId2,
      chunkKeyEpoch: 1,
      manifestKeyEpoch: 1,
      manifestRevision: 1,
    );
    final unsafeParent = File(
      p.join(
        workspace.path,
        'upload',
        'e2ee',
        'staging',
        'download',
        _mutationId1,
      ),
    );
    await unsafeParent.parent.create(recursive: true);
    await unsafeParent.writeAsString('not-a-directory', flush: true);
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: unsafeIdentity,
        persistedStoragePath: null,
        confirmedPlaintextBytes: 0,
      ),
      throwsA(isA<StateError>()),
    );

    final zeroIdentity = CloudSyncAttachmentIdentity(
      attachmentId: _mutationId2,
      uploadId: _mutationId3,
      chunkKeyEpoch: 2,
      manifestKeyEpoch: 2,
      manifestRevision: 1,
    );
    final zeroStaging = await store.openDownloadPlaintextStaging(
      identity: zeroIdentity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: zeroIdentity,
        persistedStoragePath: zeroStaging,
        confirmedPlaintextBytes: 1,
      ),
      throwsA(isA<StateError>()),
    );
    await store.appendDownloadPlaintextChunk(
      identity: zeroIdentity,
      stagingPath: zeroStaging,
      expectedOffset: 0,
      plaintext: Uint8List(0),
    );
    final emptyDigest = Uint8List.fromList(sha256.convert(const <int>[]).bytes);
    final zeroStored = await store.publishDownloadPlaintext(
      identity: zeroIdentity,
      stagingPath: zeroStaging,
      expectedPlaintextBytes: 0,
      expectedSha256: emptyDigest,
    );
    expect(await File(zeroStored.storagePath).length(), 0);
    await store.verifyContent(zeroStored);
  });

  test('账户信任成员清单双签名链覆盖初始化配对撤销与恢复绑定', () async {
    const secureCore = KelivoSecureCore();
    const manifestModule = E2eeAccountTrustManifestModule();
    final ark = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 1,
    );
    addTearDown(() => secureCore.closeAccountRootKey(ark));
    final issuer = await _newMembershipDevice(
      secureCore,
      deviceId: _issuerDeviceId,
      authGeneration: 0,
    );
    final subject = await _newMembershipDevice(
      secureCore,
      deviceId: _deviceId1,
      authGeneration: 1,
    );
    final recoveryPublicKey = await _newRecoveryPublicKey(secureCore);
    final recoveryCapsule1 = _filledBytes(80, 0x41);
    final recoveryCapsule2 = _filledBytes(80, 0x42);

    final initialized = await manifestModule.create(
      ark: ark,
      change: E2eeInitializeMembershipChange(
        userId: _userId,
        operationId: _mutationId1,
        member: issuer,
        recoveryPublicKeyVersion: 1,
        recoveryPublicKey: recoveryPublicKey,
        recoveryCapsuleVersion: 1,
        recoveryCapsule: recoveryCapsule1,
      ),
    );
    expect(initialized.manifest, hasLength(476));
    expect(
      initialized.manifest.sublist(
        initialized.manifest.length - 128,
        initialized.manifest.length - 64,
      ),
      everyElement(0),
    );
    expect(e2eeAccountTrustManifestMaximumLength, 22916);
    final initializedProjection = _membershipProjection(
      initialized,
      recoveryCapsule: recoveryCapsule1,
      lastOperationId: _mutationId1,
      dataRekeyPhase: E2eeDataRekeyPhase.ready,
    );
    final initializedFromServer = await manifestModule.verify(
      ark: ark,
      expectation: E2eeInitializeMembershipExpectation(
        projection: initializedProjection,
        operationId: _mutationId1,
        member: issuer,
      ),
    );
    final paired = await manifestModule.create(
      ark: ark,
      change: E2eeAddDeviceMembershipChange(
        previous: initializedFromServer,
        pairingId: _pairingId,
        issuerDeviceId: _issuerDeviceId,
        subject: subject,
      ),
    );
    expect(paired.manifest, hasLength(564));
    expect(paired.previousDigest, orderedEquals(initialized.digest));
    expect(
      paired.members.map((member) => member.deviceId),
      orderedEquals(<String>[_deviceId1, _issuerDeviceId]),
    );
    final pairedProjection = _membershipProjection(
      paired,
      recoveryCapsule: recoveryCapsule1,
      lastOperationId: _pairingId,
      dataRekeyPhase: E2eeDataRekeyPhase.ready,
    );
    final pairedFromServer = await manifestModule.verify(
      ark: ark,
      expectation: E2eeAddDeviceMembershipExpectation(
        projection: pairedProjection,
        previous: initializedFromServer,
        pairingId: _pairingId,
        issuerDeviceId: _issuerDeviceId,
        subject: subject,
      ),
    );
    final bootstrapped = await manifestModule.verify(
      ark: ark,
      expectation: E2eePairingBootstrapMembershipExpectation(
        projection: pairedProjection,
        consumedKeyEpoch: paired.keyEpoch,
        consumedSecurityGeneration: paired.securityGeneration,
        consumedMembershipManifestDigest: paired.digest,
        pairingId: _pairingId,
        issuerDeviceId: _issuerDeviceId,
        localMember: subject,
      ),
    );
    expect(bootstrapped.digest, orderedEquals(paired.digest));
    final pairedFromHistory = await manifestModule.verifyHistoryBatch(
      previous: initializedFromServer,
      entries: <E2eeMembershipHistoryEntry>[_membershipHistoryEntry(paired)],
    );
    expect(pairedFromHistory.digest, orderedEquals(paired.digest));

    final epoch2 = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 2,
    );
    await secureCore.addAccountRootKeyEpoch(ark, source: epoch2);
    await secureCore.closeAccountRootKey(epoch2);
    final rotated = await manifestModule.create(
      ark: ark,
      change: E2eeRevokeRotateMembershipChange(
        previous: pairedFromServer,
        operationId: _mutationId2,
        issuerDeviceId: _deviceId1,
        revokedDeviceId: _issuerDeviceId,
        nextRecoveryCapsuleVersion: 2,
        nextRecoveryCapsule: recoveryCapsule2,
      ),
    );
    expect(rotated.keyEpoch, 2);
    expect(rotated.securityGeneration, 3);
    expect(rotated.members.single.deviceId, _deviceId1);
    expect(
      rotated.currentAccountTrustPublicKey,
      isNot(orderedEquals(paired.currentAccountTrustPublicKey)),
    );
    expect(
      rotated.manifest.sublist(
        rotated.manifest.length - 128,
        rotated.manifest.length - 64,
      ),
      isNot(everyElement(0)),
    );
    final rotatedProjection = _membershipProjection(
      rotated,
      recoveryCapsule: recoveryCapsule2,
      lastOperationId: _mutationId2,
      dataRekeyPhase: E2eeDataRekeyPhase.rekeyPending,
    );
    final rotatedFromServer = await manifestModule.verify(
      ark: ark,
      expectation: E2eeRevokeRotateMembershipExpectation(
        projection: rotatedProjection,
        previous: pairedFromServer,
        operationId: _mutationId2,
        issuerDeviceId: _deviceId1,
        revokedDeviceId: _issuerDeviceId,
      ),
    );
    final rotatedFromHistory = await manifestModule.verifyHistoryBatch(
      previous: pairedFromHistory,
      entries: <E2eeMembershipHistoryEntry>[_membershipHistoryEntry(rotated)],
    );
    final recovered = await manifestModule.verifyCurrentState(
      ark: ark,
      historyHead: rotatedFromHistory,
      projection: rotatedProjection,
    );
    expect(
      recovered.membership.digest,
      orderedEquals(rotatedFromServer.digest),
    );
    expect(recovered.reportedDataRekeyPhase, E2eeDataRekeyPhase.rekeyPending);
  });

  test('成员信任链拒绝双签名篡改', () async {
    const secureCore = KelivoSecureCore();
    const manifestModule = E2eeAccountTrustManifestModule();
    final ark = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 1,
    );
    addTearDown(() => secureCore.closeAccountRootKey(ark));
    final issuer = await _newMembershipDevice(
      secureCore,
      deviceId: _issuerDeviceId,
      authGeneration: 0,
    );
    final subject = await _newMembershipDevice(
      secureCore,
      deviceId: _deviceId1,
      authGeneration: 1,
    );
    final recoveryPublicKey = await _newRecoveryPublicKey(secureCore);
    final recoveryCapsule1 = _filledBytes(80, 0x51);
    final recoveryCapsule2 = _filledBytes(80, 0x52);
    final initializeChange = E2eeInitializeMembershipChange(
      userId: _userId,
      operationId: _mutationId1,
      member: issuer,
      recoveryPublicKeyVersion: 1,
      recoveryPublicKey: recoveryPublicKey,
      recoveryCapsuleVersion: 1,
      recoveryCapsule: recoveryCapsule1,
    );
    final initialized = await manifestModule.create(
      ark: ark,
      change: initializeChange,
    );

    final paired = await manifestModule.create(
      ark: ark,
      change: E2eeAddDeviceMembershipChange(
        previous: initialized,
        pairingId: _pairingId,
        issuerDeviceId: _issuerDeviceId,
        subject: subject,
      ),
    );
    final transitionTampered = Uint8List.fromList(paired.manifest)
      ..[paired.manifest.length - 128] ^= 1;
    await expectLater(
      manifestModule.verifyHistoryBatch(
        previous: initialized,
        entries: <E2eeMembershipHistoryEntry>[
          _membershipHistoryEntryFromBytes(transitionTampered),
        ],
      ),
      throwsStateError,
    );
    final currentTampered = Uint8List.fromList(paired.manifest)
      ..[paired.manifest.length - 1] ^= 1;
    await expectLater(
      manifestModule.verifyHistoryBatch(
        previous: initialized,
        entries: <E2eeMembershipHistoryEntry>[
          _membershipHistoryEntryFromBytes(currentTampered),
        ],
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
    final pairedFromHistory = await manifestModule.verifyHistoryBatch(
      previous: initialized,
      entries: <E2eeMembershipHistoryEntry>[_membershipHistoryEntry(paired)],
    );

    final epoch2 = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 2,
    );
    await secureCore.addAccountRootKeyEpoch(ark, source: epoch2);
    await secureCore.closeAccountRootKey(epoch2);
    final rotated = await manifestModule.create(
      ark: ark,
      change: E2eeRevokeRotateMembershipChange(
        previous: paired,
        operationId: _mutationId2,
        issuerDeviceId: _deviceId1,
        revokedDeviceId: _issuerDeviceId,
        nextRecoveryCapsuleVersion: 2,
        nextRecoveryCapsule: recoveryCapsule2,
      ),
    );
    final rotationTransitionTampered = Uint8List.fromList(rotated.manifest)
      ..[rotated.manifest.length - 128] ^= 1;
    await expectLater(
      manifestModule.verifyHistoryBatch(
        previous: pairedFromHistory,
        entries: <E2eeMembershipHistoryEntry>[
          _membershipHistoryEntryFromBytes(rotationTransitionTampered),
        ],
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
    final rotatedFromHistory = await manifestModule.verifyHistoryBatch(
      previous: pairedFromHistory,
      entries: <E2eeMembershipHistoryEntry>[_membershipHistoryEntry(rotated)],
    );
    final fakeEpoch2Ark = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 2,
    );
    await expectLater(
      manifestModule.verifyCurrentState(
        ark: fakeEpoch2Ark,
        historyHead: rotatedFromHistory,
        projection: _membershipProjection(
          rotated,
          recoveryCapsule: recoveryCapsule2,
          lastOperationId: _mutationId2,
          dataRekeyPhase: E2eeDataRekeyPhase.rekeyPending,
        ),
      ),
      throwsStateError,
    );
    await secureCore.closeAccountRootKey(fakeEpoch2Ark);
  });

  test('成员清单拒绝密钥复用配对偏差计数器溢出与自撤销', () async {
    const secureCore = KelivoSecureCore();
    const manifestModule = E2eeAccountTrustManifestModule();
    final issuer = await _newMembershipDevice(
      secureCore,
      deviceId: _issuerDeviceId,
      authGeneration: 0,
    );
    final subject = await _newMembershipDevice(
      secureCore,
      deviceId: _deviceId1,
      authGeneration: 1,
    );
    final pendingSubject = await _newMembershipDevice(
      secureCore,
      deviceId: _deviceId2,
      authGeneration: 0,
    );
    expect(
      () => E2eeMembershipDeviceInput(
        deviceId: _deviceId2,
        keyVersion: 0x80000000,
        authGeneration: 0,
        signingPublicKey: pendingSubject.signingPublicKey,
        keyAgreementPublicKey: pendingSubject.keyAgreementPublicKey,
      ),
      throwsArgumentError,
    );
    expect(
      () => E2eeMembershipDeviceInput(
        deviceId: _deviceId2,
        keyVersion: 1,
        authGeneration: 0x80000000,
        signingPublicKey: pendingSubject.signingPublicKey,
        keyAgreementPublicKey: pendingSubject.keyAgreementPublicKey,
      ),
      throwsArgumentError,
    );
    expect(e2eeAccountTrustManifestMinimumLength, 476);
    expect(
      () => E2eeMembershipHistoryEntry(
        manifest: Uint8List(356),
        manifestDigest: Uint8List(32),
      ),
      throwsArgumentError,
    );
    expect(
      () => E2eeInitializeMembershipChange(
        userId: _userId,
        operationId: _mutationId1,
        member: issuer,
        recoveryPublicKeyVersion: 1,
        recoveryPublicKey: issuer.keyAgreementPublicKey,
        recoveryCapsuleVersion: 1,
        recoveryCapsule: Uint8List(
          e2eeAccountTrustManifestMaximumRecoveryCapsuleLength + 1,
        ),
      ),
      throwsArgumentError,
    );

    final recoveryPublicKey = await _newRecoveryPublicKey(secureCore);
    final recoveryCapsule = _filledBytes(80, 0x61);
    final ark = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 1,
    );
    addTearDown(() => secureCore.closeAccountRootKey(ark));
    await expectLater(
      manifestModule.create(
        ark: ark,
        change: E2eeInitializeMembershipChange(
          userId: _userId,
          operationId: _mutationId1,
          member: issuer,
          recoveryPublicKeyVersion: 1,
          recoveryPublicKey: issuer.keyAgreementPublicKey,
          recoveryCapsuleVersion: 1,
          recoveryCapsule: recoveryCapsule,
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      manifestModule.create(
        ark: ark,
        change: E2eeInitializeMembershipChange(
          userId: _userId,
          operationId: _mutationId1,
          member: E2eeMembershipDeviceInput(
            deviceId: _issuerDeviceId,
            keyVersion: 1,
            authGeneration: 0,
            signingPublicKey: Uint8List(32),
            keyAgreementPublicKey: issuer.keyAgreementPublicKey,
          ),
          recoveryPublicKeyVersion: 1,
          recoveryPublicKey: recoveryPublicKey,
          recoveryCapsuleVersion: 1,
          recoveryCapsule: recoveryCapsule,
        ),
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
    final initialized = await manifestModule.create(
      ark: ark,
      change: E2eeInitializeMembershipChange(
        userId: _userId,
        operationId: _mutationId1,
        member: issuer,
        recoveryPublicKeyVersion: 1,
        recoveryPublicKey: recoveryPublicKey,
        recoveryCapsuleVersion: 1,
        recoveryCapsule: recoveryCapsule,
      ),
    );
    final recoveryKeyReusedManifest = Uint8List.fromList(initialized.manifest)
      ..setRange(104, 136, issuer.keyAgreementPublicKey);
    await expectLater(
      manifestModule.verify(
        ark: ark,
        expectation: E2eeInitializeMembershipExpectation(
          projection: E2eeMembershipServerProjection(
            userId: initialized.userId,
            securityGeneration: initialized.securityGeneration,
            keyEpoch: initialized.keyEpoch,
            membershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
            membershipManifest: recoveryKeyReusedManifest,
            membershipManifestDigest: Uint8List.fromList(
              sha256.convert(recoveryKeyReusedManifest).bytes,
            ),
            recoveryPublicKeyVersion: initialized.recoveryPublicKeyVersion,
            recoveryPublicKey: issuer.keyAgreementPublicKey,
            recoveryCapsuleVersion: initialized.recoveryCapsuleVersion,
            recoveryCapsule: recoveryCapsule,
            lastOperationId: _mutationId1,
            dataRekeyPhase: E2eeDataRekeyPhase.ready,
          ),
          operationId: _mutationId1,
          member: issuer,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    final recoveryKeyReusedSubject = E2eeMembershipDeviceInput(
      deviceId: _deviceId2,
      keyVersion: 1,
      authGeneration: 1,
      signingPublicKey: pendingSubject.signingPublicKey,
      keyAgreementPublicKey: recoveryPublicKey,
    );
    await expectLater(
      manifestModule.create(
        ark: ark,
        change: E2eeAddDeviceMembershipChange(
          previous: initialized,
          pairingId: _pairingId,
          issuerDeviceId: _issuerDeviceId,
          subject: recoveryKeyReusedSubject,
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      manifestModule.verify(
        ark: ark,
        expectation: E2eeInitializeMembershipExpectation(
          projection: _membershipProjection(
            initialized,
            recoveryCapsule: recoveryCapsule,
            lastOperationId: _mutationId2,
            dataRekeyPhase: E2eeDataRekeyPhase.ready,
          ),
          operationId: _mutationId1,
          member: issuer,
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      manifestModule.create(
        ark: ark,
        change: E2eeAddDeviceMembershipChange(
          previous: initialized,
          pairingId: _pairingId,
          issuerDeviceId: _issuerDeviceId,
          subject: pendingSubject,
        ),
      ),
      throwsArgumentError,
    );
    final paired = await manifestModule.create(
      ark: ark,
      change: E2eeAddDeviceMembershipChange(
        previous: initialized,
        pairingId: _pairingId,
        issuerDeviceId: _issuerDeviceId,
        subject: subject,
      ),
    );
    final pairedProjection = _membershipProjection(
      paired,
      recoveryCapsule: recoveryCapsule,
      lastOperationId: _pairingId,
      dataRekeyPhase: E2eeDataRekeyPhase.ready,
    );
    await expectLater(
      manifestModule.verify(
        ark: ark,
        expectation: E2eeAddDeviceMembershipExpectation(
          projection: _membershipProjection(
            paired,
            recoveryCapsule: recoveryCapsule,
            lastOperationId: _pairingId,
            dataRekeyPhase: E2eeDataRekeyPhase.rekeyPending,
          ),
          previous: initialized,
          pairingId: _pairingId,
          issuerDeviceId: _issuerDeviceId,
          subject: subject,
        ),
      ),
      throwsStateError,
    );
    final wrongDigest = Uint8List.fromList(paired.digest)..[0] ^= 1;
    for (final expectation in <E2eePairingBootstrapMembershipExpectation>[
      E2eePairingBootstrapMembershipExpectation(
        projection: pairedProjection,
        consumedKeyEpoch: paired.keyEpoch + 1,
        consumedSecurityGeneration: paired.securityGeneration,
        consumedMembershipManifestDigest: paired.digest,
        pairingId: _pairingId,
        issuerDeviceId: _issuerDeviceId,
        localMember: subject,
      ),
      E2eePairingBootstrapMembershipExpectation(
        projection: pairedProjection,
        consumedKeyEpoch: paired.keyEpoch,
        consumedSecurityGeneration: paired.securityGeneration + 1,
        consumedMembershipManifestDigest: paired.digest,
        pairingId: _pairingId,
        issuerDeviceId: _issuerDeviceId,
        localMember: subject,
      ),
      E2eePairingBootstrapMembershipExpectation(
        projection: pairedProjection,
        consumedKeyEpoch: paired.keyEpoch,
        consumedSecurityGeneration: paired.securityGeneration,
        consumedMembershipManifestDigest: wrongDigest,
        pairingId: _pairingId,
        issuerDeviceId: _issuerDeviceId,
        localMember: subject,
      ),
    ]) {
      await expectLater(
        manifestModule.verify(ark: ark, expectation: expectation),
        throwsStateError,
      );
    }

    final epoch2 = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 2,
    );
    await secureCore.addAccountRootKeyEpoch(ark, source: epoch2);
    await secureCore.closeAccountRootKey(epoch2);
    await expectLater(
      manifestModule.create(
        ark: ark,
        change: E2eeRevokeRotateMembershipChange(
          previous: paired,
          operationId: _mutationId2,
          issuerDeviceId: _deviceId1,
          revokedDeviceId: _deviceId1,
          nextRecoveryCapsuleVersion: 2,
          nextRecoveryCapsule: _filledBytes(80, 0x62),
        ),
      ),
      throwsArgumentError,
    );
    final rotated = await manifestModule.create(
      ark: ark,
      change: E2eeRevokeRotateMembershipChange(
        previous: paired,
        operationId: _mutationId3,
        issuerDeviceId: _issuerDeviceId,
        revokedDeviceId: _deviceId1,
        nextRecoveryCapsuleVersion: 2,
        nextRecoveryCapsule: _filledBytes(80, 0x63),
      ),
    );
    await expectLater(
      manifestModule.verify(
        ark: ark,
        expectation: E2eeRevokeRotateMembershipExpectation(
          projection: _membershipProjection(
            rotated,
            recoveryCapsule: _filledBytes(80, 0x63),
            lastOperationId: _mutationId3,
            dataRekeyPhase: E2eeDataRekeyPhase.ready,
          ),
          previous: paired,
          operationId: _mutationId3,
          issuerDeviceId: _issuerDeviceId,
          revokedDeviceId: _deviceId1,
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      manifestModule.create(
        ark: ark,
        change: E2eeRevokeRotateMembershipChange(
          previous: paired,
          operationId: _mutationId2,
          issuerDeviceId: _issuerDeviceId,
          revokedDeviceId: _deviceId1,
          nextRecoveryCapsuleVersion: 2,
          nextRecoveryCapsule: recoveryCapsule,
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      manifestModule.verifyHistoryBatch(
        previous: initialized,
        entries: const <E2eeMembershipHistoryEntry>[],
      ),
      throwsArgumentError,
    );
    await expectLater(
      manifestModule.verifyHistoryBatch(
        previous: initialized,
        entries: List<E2eeMembershipHistoryEntry>.filled(
          e2eeAccountTrustManifestMaximumHistoryBatchEntries + 1,
          _membershipHistoryEntry(paired),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('恢复成员清单支持多次接续、接续后替换与 ready 直达替换', () async {
    const secureCore = KelivoSecureCore();
    const manifestModule = E2eeAccountTrustManifestModule();
    final ark = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 1,
    );
    addTearDown(() => secureCore.closeAccountRootKey(ark));
    final issuer = await _newMembershipDevice(
      secureCore,
      deviceId: _issuerDeviceId,
      authGeneration: 0,
    );
    final resumedDevice1 = await _newMembershipDevice(
      secureCore,
      deviceId: _deviceId3,
      authGeneration: 1,
    );
    final resumedDevice2 = await _newMembershipDevice(
      secureCore,
      deviceId: _deviceId4,
      authGeneration: 1,
    );
    final directDevice = await _newMembershipDevice(
      secureCore,
      deviceId: _deviceId5,
      authGeneration: 1,
    );
    final recoveryPublicKey = await _newRecoveryPublicKey(secureCore);
    final recoveryCapsule1 = _filledBytes(80, 0x71);
    final recoveryCapsule2 = _filledBytes(80, 0x72);
    final initialized = await manifestModule.create(
      ark: ark,
      change: E2eeInitializeMembershipChange(
        userId: _userId,
        operationId: _mutationId1,
        member: issuer,
        recoveryPublicKeyVersion: 1,
        recoveryPublicKey: recoveryPublicKey,
        recoveryCapsuleVersion: 1,
        recoveryCapsule: recoveryCapsule1,
      ),
    );

    final resumed1 = await manifestModule.create(
      ark: ark,
      change: E2eeRecoverResumeMembershipChange(
        previous: initialized,
        operationId: _mutationId4,
        subject: resumedDevice1,
      ),
    );
    expect(resumed1.securityGeneration, initialized.securityGeneration + 1);
    expect(resumed1.keyEpoch, initialized.keyEpoch);
    expect(
      resumed1.currentAccountTrustPublicKey,
      orderedEquals(initialized.currentAccountTrustPublicKey),
    );
    expect(resumed1.recoveryPublicKey, orderedEquals(recoveryPublicKey));
    expect(resumed1.recoveryCapsuleVersion, 1);
    expect(resumed1.recoveryCapsuleDigest, initialized.recoveryCapsuleDigest);
    expect(resumed1.issuerDeviceId, resumedDevice1.deviceId);
    expect(resumed1.subjectDeviceId, resumedDevice1.deviceId);
    expect(
      ByteData.sublistView(resumed1.manifest).getUint32(172, Endian.big),
      4,
    );
    expect(
      resumed1.manifest.sublist(
        resumed1.manifest.length - 128,
        resumed1.manifest.length - 64,
      ),
      everyElement(0),
    );
    final resumed1Verified = await manifestModule.verify(
      ark: ark,
      expectation: E2eeRecoverResumeMembershipExpectation(
        projection: _membershipProjection(
          resumed1,
          recoveryCapsule: recoveryCapsule1,
          lastOperationId: _mutationId4,
          dataRekeyPhase: E2eeDataRekeyPhase.ready,
        ),
        previous: initialized,
        operationId: _mutationId4,
        subject: resumedDevice1,
      ),
    );
    final resumed2 = await manifestModule.create(
      ark: ark,
      change: E2eeRecoverResumeMembershipChange(
        previous: resumed1Verified,
        operationId: _mutationId5,
        subject: resumedDevice2,
      ),
    );
    expect(
      resumed2.members.map((member) => member.deviceId),
      orderedEquals(<String>[_deviceId3, _deviceId4, _issuerDeviceId]),
    );

    final epoch2 = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 2,
    );
    await secureCore.addAccountRootKeyEpoch(ark, source: epoch2);
    await secureCore.closeAccountRootKey(epoch2);
    final replaced = await manifestModule.create(
      ark: ark,
      change: E2eeRecoverReplaceMembershipChange(
        previous: resumed2,
        operationId: _mutationId6,
        subject: resumedDevice2,
        nextRecoveryCapsuleVersion: 2,
        nextRecoveryCapsule: recoveryCapsule2,
      ),
    );
    expect(replaced.securityGeneration, resumed2.securityGeneration + 1);
    expect(replaced.keyEpoch, resumed2.keyEpoch + 1);
    expect(replaced.members.single.deviceId, resumedDevice2.deviceId);
    expect(replaced.issuerDeviceId, resumedDevice2.deviceId);
    expect(replaced.subjectDeviceId, resumedDevice2.deviceId);
    expect(
      replaced.recoveryPublicKeyVersion,
      resumed2.recoveryPublicKeyVersion,
    );
    expect(
      replaced.recoveryPublicKey,
      orderedEquals(resumed2.recoveryPublicKey),
    );
    expect(replaced.recoveryCapsuleVersion, 2);
    expect(
      replaced.recoveryCapsuleDigest,
      isNot(orderedEquals(resumed2.recoveryCapsuleDigest)),
    );
    expect(
      ByteData.sublistView(replaced.manifest).getUint32(172, Endian.big),
      5,
    );
    expect(
      replaced.manifest.sublist(
        replaced.manifest.length - 128,
        replaced.manifest.length - 64,
      ),
      isNot(everyElement(0)),
    );
    final replacedProjection = _membershipProjection(
      replaced,
      recoveryCapsule: recoveryCapsule2,
      lastOperationId: _mutationId6,
      dataRekeyPhase: E2eeDataRekeyPhase.rekeyPending,
    );
    await manifestModule.verify(
      ark: ark,
      expectation: E2eeRecoverReplaceMembershipExpectation(
        projection: replacedProjection,
        previous: resumed2,
        operationId: _mutationId6,
        subject: resumedDevice2,
      ),
    );
    final recoveredHistory = await manifestModule.verifyHistoryBatch(
      previous: initialized,
      entries: <E2eeMembershipHistoryEntry>[
        _membershipHistoryEntry(resumed1),
        _membershipHistoryEntry(resumed2),
        _membershipHistoryEntry(replaced),
      ],
    );
    final recoveredCurrent = await manifestModule.verifyCurrentState(
      ark: ark,
      historyHead: recoveredHistory,
      projection: replacedProjection,
    );
    expect(recoveredCurrent.membership.digest, orderedEquals(replaced.digest));

    final directReplaced = await manifestModule.create(
      ark: ark,
      change: E2eeRecoverReplaceMembershipChange(
        previous: initialized,
        operationId: _mutationId7,
        subject: directDevice,
        nextRecoveryCapsuleVersion: 2,
        nextRecoveryCapsule: recoveryCapsule2,
      ),
    );
    expect(directReplaced.members.single.deviceId, directDevice.deviceId);
    await manifestModule.verify(
      ark: ark,
      expectation: E2eeRecoverReplaceMembershipExpectation(
        projection: _membershipProjection(
          directReplaced,
          recoveryCapsule: recoveryCapsule2,
          lastOperationId: _mutationId7,
          dataRekeyPhase: E2eeDataRekeyPhase.rekeyPending,
        ),
        previous: initialized,
        operationId: _mutationId7,
        subject: directDevice,
      ),
    );
    final directHistory = await manifestModule.verifyHistoryBatch(
      previous: initialized,
      entries: <E2eeMembershipHistoryEntry>[
        _membershipHistoryEntry(directReplaced),
      ],
    );
    expect(directHistory.digest, orderedEquals(directReplaced.digest));
  });

  test('恢复成员清单拒绝篡改、历史 operationId 重复与设备材料替换', () async {
    const secureCore = KelivoSecureCore();
    const manifestModule = E2eeAccountTrustManifestModule();
    final ark = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 1,
    );
    addTearDown(() => secureCore.closeAccountRootKey(ark));
    final issuer = await _newMembershipDevice(
      secureCore,
      deviceId: _issuerDeviceId,
      authGeneration: 0,
    );
    final resumedDevice = await _newMembershipDevice(
      secureCore,
      deviceId: _deviceId3,
      authGeneration: 1,
    );
    final changedDevice = await _newMembershipDevice(
      secureCore,
      deviceId: _deviceId3,
      authGeneration: 1,
    );
    final freshDevice = await _newMembershipDevice(
      secureCore,
      deviceId: _deviceId5,
      authGeneration: 1,
    );
    final recoveryPublicKey = await _newRecoveryPublicKey(secureCore);
    final recoveryCapsule1 = _filledBytes(80, 0x81);
    final recoveryCapsule2 = _filledBytes(80, 0x82);
    final initialized = await manifestModule.create(
      ark: ark,
      change: E2eeInitializeMembershipChange(
        userId: _userId,
        operationId: _mutationId1,
        member: issuer,
        recoveryPublicKeyVersion: 1,
        recoveryPublicKey: recoveryPublicKey,
        recoveryCapsuleVersion: 1,
        recoveryCapsule: recoveryCapsule1,
      ),
    );
    final resumed = await manifestModule.create(
      ark: ark,
      change: E2eeRecoverResumeMembershipChange(
        previous: initialized,
        operationId: _mutationId4,
        subject: resumedDevice,
      ),
    );

    await expectLater(
      manifestModule.create(
        ark: ark,
        change: E2eeRecoverResumeMembershipChange(
          previous: initialized,
          operationId: _mutationId1,
          subject: resumedDevice,
        ),
      ),
      throwsStateError,
    );
    final duplicateOperation = Uint8List.fromList(resumed.manifest)
      ..setRange(176, 192, _rawUuid(_mutationId1));
    final duplicatePayload = Uint8List.sublistView(
      duplicateOperation,
      0,
      duplicateOperation.length - 128,
    );
    final duplicateSignature = await secureCore.signAccountTrustPayload(
      ark,
      userId: _rawUuid(_userId),
      keyEpoch: 1,
      canonicalPayload: duplicatePayload,
    );
    duplicateOperation.setRange(
      duplicateOperation.length - 64,
      duplicateOperation.length,
      duplicateSignature.bytes,
    );
    await expectLater(
      manifestModule.verifyHistoryBatch(
        previous: initialized,
        entries: <E2eeMembershipHistoryEntry>[
          _membershipHistoryEntryFromBytes(duplicateOperation),
        ],
      ),
      throwsStateError,
    );

    final resumeTransitionTampered = Uint8List.fromList(resumed.manifest)
      ..[resumed.manifest.length - 128] = 1;
    await expectLater(
      manifestModule.verifyHistoryBatch(
        previous: initialized,
        entries: <E2eeMembershipHistoryEntry>[
          _membershipHistoryEntryFromBytes(resumeTransitionTampered),
        ],
      ),
      throwsStateError,
    );

    final epoch2 = await secureCore.generateAccountRootKey(
      userId: _rawUuid(_userId),
      keyEpoch: 2,
    );
    await secureCore.addAccountRootKeyEpoch(ark, source: epoch2);
    await secureCore.closeAccountRootKey(epoch2);
    await expectLater(
      manifestModule.create(
        ark: ark,
        change: E2eeRecoverReplaceMembershipChange(
          previous: resumed,
          operationId: _mutationId5,
          subject: changedDevice,
          nextRecoveryCapsuleVersion: 2,
          nextRecoveryCapsule: recoveryCapsule2,
        ),
      ),
      throwsArgumentError,
    );
    final reusedOldKey = E2eeMembershipDeviceInput(
      deviceId: _deviceId5,
      keyVersion: 1,
      authGeneration: 1,
      signingPublicKey: issuer.signingPublicKey,
      keyAgreementPublicKey: freshDevice.keyAgreementPublicKey,
    );
    await expectLater(
      manifestModule.create(
        ark: ark,
        change: E2eeRecoverReplaceMembershipChange(
          previous: initialized,
          operationId: _mutationId6,
          subject: reusedOldKey,
          nextRecoveryCapsuleVersion: 2,
          nextRecoveryCapsule: recoveryCapsule2,
        ),
      ),
      throwsArgumentError,
    );
    final replaced = await manifestModule.create(
      ark: ark,
      change: E2eeRecoverReplaceMembershipChange(
        previous: resumed,
        operationId: _mutationId5,
        subject: resumedDevice,
        nextRecoveryCapsuleVersion: 2,
        nextRecoveryCapsule: recoveryCapsule2,
      ),
    );
    final replaceTransitionTampered = Uint8List.fromList(replaced.manifest)
      ..[replaced.manifest.length - 128] ^= 1;
    await expectLater(
      manifestModule.verifyHistoryBatch(
        previous: resumed,
        entries: <E2eeMembershipHistoryEntry>[
          _membershipHistoryEntryFromBytes(replaceTransitionTampered),
        ],
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
    final replaceCurrentTampered = Uint8List.fromList(replaced.manifest)
      ..[replaced.manifest.length - 1] ^= 1;
    await expectLater(
      manifestModule.verifyHistoryBatch(
        previous: resumed,
        entries: <E2eeMembershipHistoryEntry>[
          _membershipHistoryEntryFromBytes(replaceCurrentTampered),
        ],
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
  });
}

Future<E2eeMembershipDeviceInput> _newMembershipDevice(
  KelivoSecureCore secureCore, {
  required String deviceId,
  required int authGeneration,
}) async {
  final identity = await secureCore.generateDeviceIdentity();
  try {
    final publicKeys = await secureCore.readDevicePublicKeys(identity);
    return E2eeMembershipDeviceInput(
      deviceId: deviceId,
      keyVersion: 1,
      authGeneration: authGeneration,
      signingPublicKey: publicKeys.signingPublicKey,
      keyAgreementPublicKey: publicKeys.keyAgreementPublicKey,
    );
  } finally {
    await secureCore.closeDeviceIdentity(identity);
  }
}

Future<Uint8List> _newRecoveryPublicKey(KelivoSecureCore secureCore) async {
  final identity = await secureCore.generateDeviceIdentity();
  try {
    final publicKeys = await secureCore.readDevicePublicKeys(identity);
    return Uint8List.fromList(publicKeys.keyAgreementPublicKey);
  } finally {
    await secureCore.closeDeviceIdentity(identity);
  }
}

E2eeMembershipServerProjection _membershipProjection(
  E2eeVerifiedMembership membership, {
  required Uint8List recoveryCapsule,
  required String lastOperationId,
  required E2eeDataRekeyPhase dataRekeyPhase,
}) {
  return E2eeMembershipServerProjection(
    userId: membership.userId,
    securityGeneration: membership.securityGeneration,
    keyEpoch: membership.keyEpoch,
    membershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
    membershipManifest: membership.manifest,
    membershipManifestDigest: membership.digest,
    recoveryPublicKeyVersion: membership.recoveryPublicKeyVersion,
    recoveryPublicKey: membership.recoveryPublicKey,
    recoveryCapsuleVersion: membership.recoveryCapsuleVersion,
    recoveryCapsule: recoveryCapsule,
    lastOperationId: lastOperationId,
    dataRekeyPhase: dataRekeyPhase,
  );
}

E2eeMembershipHistoryEntry _membershipHistoryEntry(
  E2eeVerifiedMembership membership,
) {
  return E2eeMembershipHistoryEntry(
    manifest: membership.manifest,
    manifestDigest: membership.digest,
  );
}

E2eeMembershipHistoryEntry _membershipHistoryEntryFromBytes(
  Uint8List manifest,
) {
  return E2eeMembershipHistoryEntry(
    manifest: manifest,
    manifestDigest: Uint8List.fromList(sha256.convert(manifest).bytes),
  );
}

final class _AttachmentUploadFixture {
  _AttachmentUploadFixture._({
    required this.directory,
    required this.repository,
    required this.commands,
    required this.fileStore,
    required this.deviceStateStore,
    required this.session,
    required this.descriptor,
    required Uint8List plaintext,
    required this.transport,
    required this.clock,
  }) : plaintext = Uint8List.fromList(plaintext).asUnmodifiableView();

  final Directory directory;
  final ChatDatabaseRepository repository;
  final E2eeAttachmentUploadCommands commands;
  final _AttachmentTestFileStore fileStore;
  final DeviceStateBlobStore deviceStateStore;
  final CloudSyncAccountSession session;
  final E2eeAttachmentDescriptor descriptor;
  final Uint8List plaintext;
  final _AttachmentUploadTransport transport;
  final _MutableAttachmentClock clock;
  final KelivoSecureCore _secureCore = const KelivoSecureCore();

  E2eeAttachmentUploadCoordinator? _coordinator;
  var _uuidSequence = 0;
  var _closed = false;

  E2eeAttachmentUploadCoordinator get coordinator {
    final value = _coordinator;
    if (value == null) throw StateError('附件上传测试协调器尚未打开');
    return value;
  }

  static Future<_AttachmentUploadFixture> create({
    required Uint8List plaintext,
    _AttachmentUploadTransport? transport,
    Uint8List? descriptorContentSha256,
    bool openCoordinator = true,
    int transientVerifyFailures = 0,
    bool includePreviousKeyEpoch = false,
    int currentKeyEpoch = 7,
    int previousKeyEpoch = 6,
  }) async {
    final directory = await Directory.current.createTemp(
      'kelivo_attachment_upload_coordinator_',
    );
    ChatDatabaseRepository? repository;
    try {
      final database = AppDatabase.open(
        file: File(p.join(directory.path, 'upload.sqlite')),
        cipher: testDatabaseCipher,
      );
      await database.customSelect('SELECT 1;').getSingle();
      repository = ChatDatabaseRepository(
        database,
        databaseCipher: testDatabaseCipher,
      );
      const secureCore = KelivoSecureCore();
      final deviceStateStore = DeviceStateBlobStore(
        installationRoot: directory,
      );
      final nonce = sha256
          .convert(utf8.encode(directory.path))
          .toString()
          .substring(0, 16);
      final session = await _seedAccountKeyLeaseState(
        core: secureCore,
        store: deviceStateStore,
        baseUrl: 'https://upload-$nonce.example.com',
        loginName: 'upload-$nonce',
        includePreviousKeyEpoch: includePreviousKeyEpoch,
        currentKeyEpoch: currentKeyEpoch,
        previousKeyEpoch: previousKeyEpoch,
      );
      final dataKey = await secureCore.generateAttachmentDataKey();
      final attachmentId = _uuidStringForTest(dataKey.attachmentId);
      final keyLease = await E2eeAccountKeyLease.open(
        session: session,
        deviceStateStore: deviceStateStore,
        secureCore: secureCore,
      );
      final ark = keyLease.takeAccountRootKeyOwnership();
      late Uint8List wrappedDataKey;
      try {
        wrappedDataKey = await secureCore.wrapAttachmentDataKey(
          ark,
          dataKey.key,
          context: KelivoAttachmentContext(
            userId: _rawUuid(session.userId),
            attachmentId: dataKey.attachmentId,
            keyEpoch: session.keyEpoch,
          ),
        );
      } finally {
        await secureCore.closeAttachmentDataKey(dataKey.key);
        await secureCore.closeAccountRootKey(ark);
        await keyLease.close();
      }

      final baseFileStore = E2eeAttachmentMemoryFileStore();
      final actualDigest = Uint8List.fromList(sha256.convert(plaintext).bytes);
      final source = await baseFileStore.publish(
        location: E2eeAttachmentFileLocation.content(
          contentSha256: actualDigest,
        ),
        source: Stream<List<int>>.value(plaintext),
      );
      final fileStore = _AttachmentTestFileStore(
        baseFileStore,
        transientVerifyFailures: transientVerifyFailures,
      );
      final layout = KelivoAttachmentLayout(
        totalPlaintextBytes: plaintext.length,
      );
      final descriptor = E2eeAttachmentDescriptor(
        attachmentId: attachmentId,
        chunkKeyEpoch: session.keyEpoch,
        kind: E2eeAttachmentKind.file,
        totalPlaintextBytes: plaintext.length,
        contentSha256: descriptorContentSha256 ?? actualDigest,
        wrappedDataKey: wrappedDataKey,
        chunkCiphertextBytes: <int>[
          for (var index = 0; index < layout.chunkCount; index++)
            layout.plaintextLengthForChunk(index) +
                KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
        ],
        displayName: 'upload.bin',
        mediaType: 'application/octet-stream',
      );
      const targetRevisionId = 'attachment-upload-message';
      const localAssetId = 'attachment-upload-test';
      final assetTimestamp = DateTime.utc(2026, 7, 29, 8);
      await database
          .into(database.conversationRows)
          .insert(
            ConversationRowsCompanion.insert(
              id: 'attachment-upload-conversation',
              title: 'Attachment upload',
              createdAt: assetTimestamp,
              updatedAt: assetTimestamp,
            ),
          );
      await database
          .into(database.messageRows)
          .insert(
            MessageRowsCompanion.insert(
              id: targetRevisionId,
              conversationId: 'attachment-upload-conversation',
              role: 'user',
              content: '',
              timestamp: assetTimestamp,
              turnId: 'attachment-upload-turn',
              generationStatus: 'completed',
              messageOrder: 0,
            ),
          );
      await database
          .into(database.assetRows)
          .insert(
            AssetRowsCompanion.insert(
              id: localAssetId,
              contentHash: descriptor.contentSha256
                  .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                  .join(),
              path: source.storagePath,
              byteSize: plaintext.length,
              createdAt: assetTimestamp,
              lastReferencedAt: assetTimestamp,
            ),
          );
      await database
          .into(database.messageAssetRows)
          .insert(
            MessageAssetRowsCompanion.insert(
              revisionId: targetRevisionId,
              ordinal: 0,
              assetId: localAssetId,
              kind: E2eeAttachmentKind.file.name,
              displayName: const Value('upload.bin'),
              mediaType: const Value('application/octet-stream'),
            ),
          );
      final commands = repository.e2eeAttachmentUploadCommands;
      final clock = _MutableAttachmentClock(DateTime.utc(2026, 7, 29, 8));
      await commands.create(
        draft: E2eeAttachmentUploadDraft(
          descriptor: descriptor,
          localAssetId: localAssetId,
          targetRevisionId: targetRevisionId,
          targetOrdinal: 0,
          sourcePath: source.storagePath,
          createMutationId: _mutationId1,
          commitMutationId: _mutationId2,
        ),
        now: clock.value,
      );
      final fixture = _AttachmentUploadFixture._(
        directory: directory,
        repository: repository,
        commands: commands,
        fileStore: fileStore,
        deviceStateStore: deviceStateStore,
        session: session,
        descriptor: descriptor,
        plaintext: plaintext,
        transport: transport ?? _AttachmentUploadTransport(),
        clock: clock,
      );
      if (openCoordinator) await fixture._openCoordinator();
      return fixture;
    } catch (_) {
      if (repository != null) await repository.close();
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<E2eeAttachmentCryptoSession> openCryptoSession() {
    return E2eeAttachmentCryptoSession.open(
      session: session,
      deviceStateStore: deviceStateStore,
      secureCore: _secureCore,
    );
  }

  Future<void> restartCoordinator() async {
    await _coordinator?.close();
    _coordinator = null;
    await _openCoordinator();
  }

  Future<void> _openCoordinator() async {
    final cryptoSession = await openCryptoSession();
    _coordinator = E2eeAttachmentUploadCoordinator.takeOwnership(
      commands: commands,
      fileStore: fileStore,
      transport: transport,
      token: session.token,
      cryptoSession: cryptoSession,
      utcNow: clock.call,
      newUuid: _nextUuid,
    );
  }

  String _nextUuid() {
    _uuidSequence++;
    return 'a0000000-0000-4000-8000-'
        '${_uuidSequence.toRadixString(16).padLeft(12, '0')}';
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _coordinator?.close();
    await repository.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

final class _MutableAttachmentClock {
  _MutableAttachmentClock(this.value);

  DateTime value;

  DateTime call() => value;
}

final class _AttachmentCancellationSignal
    implements E2eeSyncCancellationSignal {
  final Set<void Function()> _listeners = <void Function()>{};
  bool _cancelled = false;

  @override
  E2eeSyncCancellationRegistration register(void Function() onCancelled) {
    if (_cancelled) {
      onCancelled();
      return _AttachmentCancellationRegistration.noop();
    }
    _listeners.add(onCancelled);
    return _AttachmentCancellationRegistration(() {
      _listeners.remove(onCancelled);
    });
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = _listeners.toList(growable: false);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

final class _AttachmentCancellationRegistration
    implements E2eeSyncCancellationRegistration {
  _AttachmentCancellationRegistration.noop() : _unregister = null;

  _AttachmentCancellationRegistration(this._unregister);

  final void Function()? _unregister;
  bool _registered = true;

  @override
  void unregister() {
    if (!_registered) return;
    _registered = false;
    _unregister?.call();
  }
}

final class _AttachmentTestFileStore implements E2eeAttachmentFileStore {
  _AttachmentTestFileStore(this._delegate, {this.transientVerifyFailures = 0});

  final E2eeAttachmentFileStore _delegate;
  int transientVerifyFailures;
  bool rejectPendingReads = false;
  bool reportPendingMissing = false;
  void Function()? beforeReadVerified;
  void Function()? beforeOpenVerifiedContent;
  void Function()? beforeVerifiedChunkRead;
  void Function()? beforePublish;
  void Function(E2eeAttachmentStoredFile stored)? afterPublish;
  int verifiedContentCloseFailures = 0;
  int verifiedContentOpens = 0;
  int completedVerifiedReads = 0;
  int verifiedChunkReads = 0;
  int unverifiedRangeReads = 0;

  @override
  Future<E2eeAttachmentStoredFile> publish({
    required E2eeAttachmentFileLocation location,
    required Stream<List<int>> source,
    E2eeAttachmentCheckCanContinue? checkCanContinue,
  }) async {
    beforePublish?.call();
    checkCanContinue?.call();
    final stored = await _delegate.publish(
      location: location,
      source: source,
      checkCanContinue: checkCanContinue,
    );
    afterPublish?.call(stored);
    return stored;
  }

  @override
  Future<Uint8List> readVerified(
    E2eeAttachmentStoredFile storedFile, {
    E2eeAttachmentCheckCanContinue? checkCanContinue,
  }) async {
    beforeReadVerified?.call();
    checkCanContinue?.call();
    if (rejectPendingReads) {
      if (reportPendingMissing) {
        throw FileSystemException(
          'e2ee_attachment_file_missing',
          storedFile.storagePath,
        );
      }
      throw const FormatException('e2ee_attachment_file_integrity');
    }
    final bytes = await _delegate.readVerified(
      storedFile,
      checkCanContinue: checkCanContinue,
    );
    completedVerifiedReads++;
    return bytes;
  }

  @override
  Future<Uint8List> readContentRange({
    required E2eeAttachmentStoredFile storedFile,
    required int offset,
    required int length,
  }) {
    unverifiedRangeReads++;
    return _delegate.readContentRange(
      storedFile: storedFile,
      offset: offset,
      length: length,
    );
  }

  @override
  Future<E2eeAttachmentVerifiedContent> openVerifiedContent({
    required E2eeAttachmentStoredFile storedFile,
    required List<int> chunkPlaintextBytes,
    E2eeAttachmentCheckCanContinue? checkCanContinue,
  }) async {
    beforeOpenVerifiedContent?.call();
    checkCanContinue?.call();
    if (transientVerifyFailures > 0) {
      transientVerifyFailures--;
      throw FileSystemException('temporary-sharing-violation');
    }
    final reader = await _delegate.openVerifiedContent(
      storedFile: storedFile,
      chunkPlaintextBytes: chunkPlaintextBytes,
      checkCanContinue: checkCanContinue,
    );
    verifiedContentOpens++;
    return _AttachmentTestVerifiedContent(reader, this);
  }

  @override
  Future<String> resolveContentStoragePath(Uint8List contentSha256) {
    return _delegate.resolveContentStoragePath(contentSha256);
  }

  @override
  Future<String> openDownloadPlaintextStaging({
    required CloudSyncAttachmentIdentity identity,
    required String? persistedStoragePath,
    required int confirmedPlaintextBytes,
  }) {
    return _delegate.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: persistedStoragePath,
      confirmedPlaintextBytes: confirmedPlaintextBytes,
    );
  }

  @override
  Future<void> appendDownloadPlaintextChunk({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedOffset,
    required Uint8List plaintext,
  }) {
    return _delegate.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: expectedOffset,
      plaintext: plaintext,
    );
  }

  @override
  Future<E2eeAttachmentStoredFile> publishDownloadPlaintext({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedPlaintextBytes,
    required Uint8List expectedSha256,
  }) {
    return _delegate.publishDownloadPlaintext(
      identity: identity,
      stagingPath: stagingPath,
      expectedPlaintextBytes: expectedPlaintextBytes,
      expectedSha256: expectedSha256,
    );
  }

  @override
  Future<void> verifyContent(E2eeAttachmentStoredFile storedFile) {
    return _delegate.verifyContent(storedFile);
  }

  @override
  Future<void> deleteStaging({required String storagePath}) {
    return _delegate.deleteStaging(storagePath: storagePath);
  }
}

final class _AttachmentTestVerifiedContent
    implements E2eeAttachmentVerifiedContent {
  const _AttachmentTestVerifiedContent(this._delegate, this._owner);

  final E2eeAttachmentVerifiedContent _delegate;
  final _AttachmentTestFileStore _owner;

  @override
  Future<Uint8List> readChunk(
    int chunkIndex, {
    E2eeAttachmentCheckCanContinue? checkCanContinue,
  }) {
    _owner.verifiedChunkReads++;
    _owner.beforeVerifiedChunkRead?.call();
    checkCanContinue?.call();
    return _delegate.readChunk(chunkIndex, checkCanContinue: checkCanContinue);
  }

  @override
  Future<void> close() {
    if (_owner.verifiedContentCloseFailures > 0) {
      _owner.verifiedContentCloseFailures--;
      throw FileSystemException('temporary-close-failure');
    }
    return _delegate.close();
  }
}

final class _AttachmentPutAttempt {
  _AttachmentPutAttempt({
    required this.mutationId,
    required this.chunkIndex,
    required Uint8List ciphertext,
  }) : ciphertext = Uint8List.fromList(ciphertext).asUnmodifiableView();

  final String mutationId;
  final int chunkIndex;
  final Uint8List ciphertext;
}

final class _AttachmentUploadTransport implements CloudSyncAttachmentTransport {
  _AttachmentUploadTransport({
    this.retryablePutFailuresRemaining = 0,
    this.permanentPutFailure,
    this.createFailure,
    this.returnInvalidCreateResponse = false,
  });

  int retryablePutFailuresRemaining;
  final CloudSyncException? permanentPutFailure;
  CloudSyncException? createFailure;
  final bool returnInvalidCreateResponse;
  CloudSyncException? putFailure;
  CloudSyncException? commitFailure;
  Future<void> Function()? beforeCreate;
  Future<void> Function()? beforePut;
  Future<void> Function()? beforeCommit;
  void Function()? afterCreate;
  void Function()? afterPut;
  void Function()? afterCommit;
  final List<CloudSyncAttachmentCreateUploadRequest> createRequests =
      <CloudSyncAttachmentCreateUploadRequest>[];
  final List<_AttachmentPutAttempt> putAttempts = <_AttachmentPutAttempt>[];
  final List<CloudSyncAttachmentCommitUploadRequest> commitRequests =
      <CloudSyncAttachmentCommitUploadRequest>[];

  int get remoteCalls =>
      createRequests.length + putAttempts.length + commitRequests.length;

  @override
  Future<CloudSyncAttachmentUpload> createAttachmentUpload({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentCreateUploadRequest request,
  }) async {
    createRequests.add(request);
    await beforeCreate?.call();
    afterCreate?.call();
    final failure = createFailure;
    if (failure != null) throw failure;
    return CloudSyncAttachmentUpload(
      identity: CloudSyncAttachmentIdentity(
        attachmentId: returnInvalidCreateResponse
            ? _mutationId3
            : request.attachmentId,
        uploadId: _uploadId,
        chunkKeyEpoch: request.chunkKeyEpoch,
        manifestKeyEpoch: request.manifestKeyEpoch,
        manifestRevision: request.manifestRevision,
      ),
      chunkCount: request.chunkCount,
      totalCiphertextBytes: request.totalCiphertextBytes,
      createdAt: DateTime.utc(2026, 7, 29, 8),
    );
  }

  @override
  Future<CloudSyncAttachmentStoredChunk> putAttachmentChunk({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentPutChunkRequest request,
  }) async {
    putAttempts.add(
      _AttachmentPutAttempt(
        mutationId: request.mutationId,
        chunkIndex: request.chunk.chunkIndex,
        ciphertext: request.ciphertext,
      ),
    );
    await beforePut?.call();
    afterPut?.call();
    if (retryablePutFailuresRemaining > 0) {
      retryablePutFailuresRemaining--;
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.network,
        retryable: true,
      );
    }
    final permanent = putFailure ?? permanentPutFailure;
    if (permanent != null) throw permanent;
    return CloudSyncAttachmentStoredChunk(
      chunk: request.chunk,
      ciphertextBytes: request.ciphertext.length,
    );
  }

  @override
  Future<CloudSyncAttachmentCommittedUpload> commitAttachmentUpload({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentCommitUploadRequest request,
  }) async {
    commitRequests.add(request);
    await beforeCommit?.call();
    afterCommit?.call();
    final failure = commitFailure;
    if (failure != null) throw failure;
    return CloudSyncAttachmentCommittedUpload(
      identity: request.identity,
      committedAt: DateTime.utc(2026, 7, 29, 8, 1),
    );
  }

  @override
  Future<CloudSyncAttachmentManifest> getAttachmentManifest({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentIdentity identity,
  }) {
    throw UnsupportedError('上传协调器测试不读取远端清单');
  }

  @override
  Future<CloudSyncAttachmentChunk> getAttachmentChunk({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentChunkIdentity chunk,
  }) {
    throw UnsupportedError('上传协调器测试不下载远端分块');
  }

  @override
  Future<CloudSyncAttachmentDeleted> deleteAttachment({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentDeleteRequest request,
  }) {
    throw UnsupportedError('上传协调器测试不删除远端附件');
  }
}

Future<HttpRequest> _nextAttachmentRequest(
  StreamIterator<HttpRequest> requests,
) async {
  if (!await requests.moveNext()) {
    throw StateError('附件测试服务提前关闭');
  }
  return requests.current;
}

Future<void> _expectAttachmentRequest(
  HttpRequest request, {
  required String path,
  required Map<String, Object?> body,
}) async {
  expect(request.method, 'POST');
  expect(request.uri.path, path);
  expect(
    request.headers.value(HttpHeaders.authorizationHeader),
    'Bearer $_fullTokenValue',
  );
  expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
  expect(jsonDecode(await utf8.decoder.bind(request).join()), body);
}

Future<void> _writeJsonResponse(
  HttpRequest request,
  Map<String, Object?> body, {
  int statusCode = HttpStatus.ok,
}) async {
  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

Uint8List _authenticatorSlotId(String baseUrl, String loginName) {
  final digest = sha256.convert(
    utf8.encode(
      'kelivo.e2ee.device-state.slot.v1\u0000$baseUrl\u0000$loginName',
    ),
  );
  return Uint8List.fromList(digest.bytes.sublist(0, 16));
}

Uint8List _pairingRecoveryRecordId(String baseUrl, String loginName) {
  final digest = sha256.convert(
    utf8.encode(
      'kelivo.e2ee.pairing-transaction.record.v1\u0000'
      '$baseUrl\u0000$loginName',
    ),
  );
  return Uint8List.fromList(digest.bytes.sublist(0, 16));
}

Uint8List _pairingRecoveryAssociatedData(String baseUrl, String loginName) {
  return Uint8List.fromList(
    utf8.encode(
      'kelivo.e2ee.pairing-transaction.aad.v1\u0000'
      '$baseUrl\u0000$loginName',
    ),
  );
}

Future<CloudSyncAccountSession> _seedAccountKeyLeaseState({
  required KelivoSecureCore core,
  required DeviceStateBlobStore store,
  required String baseUrl,
  required String loginName,
  bool bound = true,
  bool includePreviousKeyEpoch = false,
  int currentKeyEpoch = 7,
  int previousKeyEpoch = 6,
}) async {
  final key = await core.createSlot(
    E2eeDeviceStateAccess.deriveSlotId(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
    ),
  );
  final identity = await core.generateDeviceIdentity();
  KelivoAccountRootKeyHandle? ark;
  KelivoAccountRootKeyHandle? nextArk;
  try {
    if (bound) {
      ark = await core.generateAccountRootKey(
        userId: _rawUuid(_userId),
        keyEpoch: includePreviousKeyEpoch ? previousKeyEpoch : currentKeyEpoch,
      );
      if (includePreviousKeyEpoch) {
        nextArk = await core.generateAccountRootKey(
          userId: _rawUuid(_userId),
          keyEpoch: currentKeyEpoch,
        );
        await core.addAccountRootKeyEpoch(ark, source: nextArk);
      }
    }
    final blob = await core.sealDeviceState(
      key,
      identity,
      deviceId: _rawUuid(_deviceId1),
      keyVersion: 3,
      ark: ark,
      account: bound
          ? KelivoDeviceStateAccountBinding(
              userId: _rawUuid(_userId),
              keyEpoch: currentKeyEpoch,
            )
          : null,
    );
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: blob,
    );
  } finally {
    if (nextArk != null) await core.closeAccountRootKey(nextArk);
    if (ark != null) await core.closeAccountRootKey(ark);
    await core.closeDeviceIdentity(identity);
    await core.close(key);
  }
  return _accountKeyLeaseSession(
    baseUrl: baseUrl,
    loginName: loginName,
    keyEpoch: currentKeyEpoch,
  );
}

CloudSyncAccountSession _accountKeyLeaseSession({
  required String baseUrl,
  required String loginName,
  String userId = _userId,
  String deviceId = _deviceId1,
  int keyEpoch = 7,
  int deviceKeyVersion = 3,
}) {
  return CloudSyncAccountSession(
    baseUrl: baseUrl,
    token: _fullToken,
    tokenExpiresAt: DateTime.utc(2030),
    keyEpoch: keyEpoch,
    authGeneration: 0,
    sessionGeneration: 1,
    userId: userId,
    loginName: loginName,
    displayName: 'Lease User',
    role: CloudSyncUserRole.user,
    attachmentQuotaBytes: 1024,
    deviceId: deviceId,
    deviceName: 'Lease Device',
    platform: CloudSyncPlatform.windows,
    clientVersion: '1.0.0',
    deviceKeyVersion: deviceKeyVersion,
    deviceCreatedAt: DateTime.utc(2026),
  );
}

Uint8List _rawUuid(String value) {
  final hex = value.replaceAll('-', '');
  return Uint8List.fromList(<int>[
    for (var offset = 0; offset < hex.length; offset += 2)
      int.parse(hex.substring(offset, offset + 2), radix: 16),
  ]);
}

String _uuidStringForTest(Uint8List value) {
  final hex = value
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

Uint8List _encodeLegacyAttachmentManifestV1({
  required E2eeAttachmentDescriptor descriptor,
  required String uploadId,
}) {
  const wrappedDataKeyOffset = 94;
  final headerBytes =
      wrappedDataKeyOffset + KelivoAttachmentLimits.wrappedDataKeyBytes;
  final displayNameBytes = descriptor.displayName == null
      ? Uint8List(0)
      : Uint8List.fromList(utf8.encode(descriptor.displayName!));
  final mediaTypeBytes = descriptor.mediaType == null
      ? Uint8List(0)
      : Uint8List.fromList(ascii.encode(descriptor.mediaType!));
  final frame = Uint8List(
    headerBytes +
        descriptor.chunkCiphertextBytes.length * 4 +
        displayNameBytes.length +
        mediaTypeBytes.length,
  );
  final fields = ByteData.sublistView(frame);
  frame.setRange(0, 8, ascii.encode('KELVAM01'));
  fields.setUint16(8, 1, Endian.big);
  fields.setUint8(10, descriptor.kind.wireValue);
  frame.setRange(12, 28, _rawUuid(descriptor.attachmentId));
  frame.setRange(28, 44, _rawUuid(uploadId));
  fields.setUint32(44, descriptor.chunkKeyEpoch, Endian.big);
  fields.setUint64(48, descriptor.totalPlaintextBytes, Endian.big);
  fields.setUint16(56, descriptor.chunkCiphertextBytes.length, Endian.big);
  fields.setUint16(58, displayNameBytes.length, Endian.big);
  fields.setUint16(60, mediaTypeBytes.length, Endian.big);
  frame.setRange(62, wrappedDataKeyOffset, descriptor.contentSha256);
  frame.setRange(wrappedDataKeyOffset, headerBytes, descriptor.wrappedDataKey);
  var offset = headerBytes;
  for (final chunkLength in descriptor.chunkCiphertextBytes) {
    fields.setUint32(offset, chunkLength, Endian.big);
    offset += 4;
  }
  frame.setRange(offset, offset + displayNameBytes.length, displayNameBytes);
  offset += displayNameBytes.length;
  frame.setRange(offset, offset + mediaTypeBytes.length, mediaTypeBytes);
  displayNameBytes.fillRange(0, displayNameBytes.length, 0);
  mediaTypeBytes.fillRange(0, mediaTypeBytes.length, 0);
  return frame;
}

Future<
  ({Map<String, Object?> expectedRequest, Map<String, Object?> securityState})
>
_seedPendingRegistration({
  required KelivoSecureCore core,
  required DeviceStateBlobStore store,
  required String baseUrl,
  required String loginName,
  required DateTime attemptExpiresAt,
}) async {
  final registrationUpload = _filledBytes(
    cloudSyncOpaqueRegistrationUploadBytes,
    0x51,
  );
  final accountKeyEnvelope = _filledBytes(
    cloudSyncAccountKeyEnvelopeBytes,
    0x52,
  );
  final deviceProof = _filledBytes(cloudSyncDeviceProofBytes, 0x53);
  final recoveryPublicKey = _filledBytes(cloudSyncRecoveryPublicKeyBytes, 0x54);
  final recoveryCapsule = _filledBytes(cloudSyncRecoveryCapsuleBytes, 0x55);
  final key = await core.createSlot(_authenticatorSlotId(baseUrl, loginName));
  final identity = await core.generateDeviceIdentity();
  final deviceId = _rawUuid(_deviceId1);
  final userId = _rawUuid(_userId);
  final ark = await core.generateAccountRootKey(userId: userId, keyEpoch: 1);
  final publicKeys = await core.readDevicePublicKeys(identity);
  final membership = await const E2eeAccountTrustManifestModule().create(
    ark: ark,
    change: E2eeInitializeMembershipChange(
      userId: _userId,
      operationId: _attemptId1,
      member: E2eeMembershipDeviceInput(
        deviceId: _deviceId1,
        keyVersion: 1,
        authGeneration: 0,
        signingPublicKey: publicKeys.signingPublicKey,
        keyAgreementPublicKey: publicKeys.keyAgreementPublicKey,
      ),
      recoveryPublicKeyVersion: 1,
      recoveryPublicKey: recoveryPublicKey,
      recoveryCapsuleVersion: 1,
      recoveryCapsule: recoveryCapsule,
    ),
  );
  final genesis = CloudSyncGenesisSecurityState(
    operationId: membership.operationId,
    membershipManifest: membership.manifest,
    membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
      membership.digest,
    ),
    recoveryPublicKeyVersion: membership.recoveryPublicKeyVersion,
    recoveryPublicKey: recoveryPublicKey,
    recoveryCapsuleVersion: membership.recoveryCapsuleVersion,
    recoveryCapsule: recoveryCapsule,
  );
  final expectedRequest = <String, Object?>{
    'protocolVersion': cloudSyncOpaqueProtocolVersion,
    'attemptId': _attemptId1,
    'registrationUpload': _encodedData(registrationUpload),
    'accountKeyEnvelope': _encodedData(accountKeyEnvelope),
    'securityState': <String, Object?>{
      'generation': 1,
      'operationId': genesis.operationId,
      'keyEpoch': 1,
      'membershipManifest': _encodedData(genesis.membershipManifest),
      'membershipManifestDigest': genesis.membershipManifestDigest.encoded,
      'recoveryPublicKeyVersion': genesis.recoveryPublicKeyVersion,
      'recoveryPublicKey': _encodedData(genesis.recoveryPublicKey),
      'recoveryCapsuleVersion': genesis.recoveryCapsuleVersion,
      'recoveryCapsule': _encodedData(genesis.recoveryCapsule),
    },
    'deviceProof': _encodedData(deviceProof),
  };
  final securityState = _registrationSecurityStateData(
    securityState: genesis,
    accountKeyEnvelope: accountKeyEnvelope,
  );
  final identityOnlyState = Uint8List.fromList(
    await core.sealDeviceState(
      key,
      identity,
      deviceId: deviceId,
      keyVersion: 1,
    ),
  );
  final fullState = Uint8List.fromList(
    await core.sealDeviceState(
      key,
      identity,
      deviceId: deviceId,
      keyVersion: 1,
      ark: ark,
      account: KelivoDeviceStateAccountBinding(userId: userId, keyEpoch: 1),
    ),
  );
  const registrationHeaderLength = 120;
  const registrationUploadOffset = registrationHeaderLength;
  const registrationEnvelopeOffset =
      registrationUploadOffset + cloudSyncOpaqueRegistrationUploadBytes;
  const registrationProofOffset =
      registrationEnvelopeOffset + cloudSyncAccountKeyEnvelopeBytes;
  const registrationStateOffset =
      registrationProofOffset + cloudSyncDeviceProofBytes;
  const registrationManifestOffset =
      registrationStateOffset + DeviceStateBlobStore.blobLength;
  const registrationManifestDigestOffset =
      registrationManifestOffset + cloudSyncMembershipManifestMinimumBytes;
  const registrationRecoveryPublicKeyOffset =
      registrationManifestDigestOffset + cloudSyncMembershipManifestDigestBytes;
  const registrationRecoveryCapsuleOffset =
      registrationRecoveryPublicKeyOffset + cloudSyncRecoveryPublicKeyBytes;
  const registrationFrameLength =
      registrationRecoveryCapsuleOffset + cloudSyncRecoveryCapsuleBytes;
  final frame = Uint8List(registrationFrameLength);
  final magic = ascii.encode('KELVRT02');
  frame.setRange(0, magic.length, magic);
  final fields = ByteData.sublistView(frame);
  fields.setUint16(8, 2, Endian.big);
  fields.setUint16(10, 0, Endian.big);
  fields.setUint32(12, 1, Endian.big);
  fields.setUint32(16, 1, Endian.big);
  fields.setUint32(20, genesis.recoveryPublicKeyVersion, Endian.big);
  fields.setUint32(24, genesis.recoveryCapsuleVersion, Endian.big);
  fields.setUint32(28, 0, Endian.big);
  fields.setUint64(
    32,
    attemptExpiresAt.toUtc().millisecondsSinceEpoch,
    Endian.big,
  );
  frame.setRange(40, 56, _rawUuid(_attemptId1));
  frame.setRange(56, 72, userId);
  frame.setRange(72, 88, _rawUuid(_accountContextId));
  frame.setRange(88, 104, deviceId);
  frame.setRange(104, 120, _rawUuid(genesis.operationId));
  frame.setRange(
    registrationUploadOffset,
    registrationEnvelopeOffset,
    registrationUpload,
  );
  frame.setRange(
    registrationEnvelopeOffset,
    registrationProofOffset,
    accountKeyEnvelope,
  );
  frame.setRange(registrationProofOffset, registrationStateOffset, deviceProof);
  frame.setRange(
    registrationStateOffset,
    registrationManifestOffset,
    fullState,
  );
  frame.setRange(
    registrationManifestOffset,
    registrationManifestDigestOffset,
    genesis.membershipManifest,
  );
  frame.setRange(
    registrationManifestDigestOffset,
    registrationRecoveryPublicKeyOffset,
    genesis.membershipManifestDigest.bytes,
  );
  frame.setRange(
    registrationRecoveryPublicKeyOffset,
    registrationRecoveryCapsuleOffset,
    genesis.recoveryPublicKey,
  );
  frame.setRange(
    registrationRecoveryCapsuleOffset,
    registrationFrameLength,
    genesis.recoveryCapsule,
  );
  final recordId = Uint8List.fromList(
    sha256
        .convert(
          utf8.encode(
            'kelivo.e2ee.registration-transaction.record.v1\u0000'
            '$baseUrl\u0000$loginName',
          ),
        )
        .bytes
        .sublist(0, 16),
  );
  final associatedData = Uint8List.fromList(
    utf8.encode(
      'kelivo.e2ee.registration-transaction.aad.v1\u0000'
      '$baseUrl\u0000$loginName',
    ),
  );
  try {
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: identityOnlyState,
    );
    final envelope = await core.sealRecord(
      key,
      recordId: recordId,
      epoch: 1,
      associatedData: associatedData,
      plaintext: frame,
    );
    await store.writePendingRegistrationEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: envelope,
    );
  } finally {
    frame.fillRange(0, frame.length, 0);
    identityOnlyState.fillRange(0, identityOnlyState.length, 0);
    fullState.fillRange(0, fullState.length, 0);
    registrationUpload.fillRange(0, registrationUpload.length, 0);
    accountKeyEnvelope.fillRange(0, accountKeyEnvelope.length, 0);
    deviceProof.fillRange(0, deviceProof.length, 0);
    recoveryPublicKey.fillRange(0, recoveryPublicKey.length, 0);
    recoveryCapsule.fillRange(0, recoveryCapsule.length, 0);
    recordId.fillRange(0, recordId.length, 0);
    associatedData.fillRange(0, associatedData.length, 0);
    await core.closeAccountRootKey(ark);
    await core.closeDeviceIdentity(identity);
    await core.close(key);
  }
  return (expectedRequest: expectedRequest, securityState: securityState);
}
