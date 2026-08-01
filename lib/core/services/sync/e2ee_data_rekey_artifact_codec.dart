import 'dart:convert';
import 'dart:typed_data';

import 'cloud_sync_types.dart';
import 'e2ee_data_rekey_wire.dart';

const e2eeDataRekeyArtifactMaximumBytes = 1400000;

final _artifactUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _canonicalBase64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+$');

final class E2eeDataRekeyArtifactBinding {
  E2eeDataRekeyArtifactBinding({
    required String userId,
    required String issuerDeviceId,
    required this.operation,
  }) : userId = _requireArtifactUuid(userId, 'userId'),
       issuerDeviceId = _requireArtifactUuid(issuerDeviceId, 'issuerDeviceId');

  final String userId;
  final String issuerDeviceId;
  final CloudSyncDataRekeyOperationScope operation;

  @override
  bool operator ==(Object other) {
    if (other is! E2eeDataRekeyArtifactBinding) return false;
    final left = operation;
    final right = other.operation;
    return userId == other.userId &&
        issuerDeviceId == other.issuerDeviceId &&
        left.operationId == right.operationId &&
        left.sourceDataGeneration == right.sourceDataGeneration &&
        left.sourceKeyEpoch == right.sourceKeyEpoch &&
        left.targetKeyEpoch == right.targetKeyEpoch;
  }

  @override
  int get hashCode => Object.hash(
    userId,
    issuerDeviceId,
    operation.operationId,
    operation.sourceDataGeneration,
    operation.sourceKeyEpoch,
    operation.targetKeyEpoch,
  );
}

sealed class E2eeDataRekeyStageArtifact {
  const E2eeDataRekeyStageArtifact({
    required this.binding,
    required this.activeLease,
    required this.mutationId,
  });

  final E2eeDataRekeyArtifactBinding binding;
  final CloudSyncDataRekeyActiveLease activeLease;
  final String mutationId;

  String get artifactId => mutationId;

  Uint8List encode();

  static E2eeDataRekeyStageArtifact decode(
    Uint8List bytes, {
    required E2eeDataRekeyArtifactBinding expectedBinding,
  }) {
    final json = _decodeArtifactJson(bytes);
    final kind = _requireArtifactString(json, 'kind');
    final common = _decodeCommon(json, expectedBinding: expectedBinding);
    return switch (kind) {
      _recordRequestKind => E2eeDataRekeyPendingRecordArtifact._fromJson(
        json,
        common,
      ),
      _recordConfirmedKind => E2eeDataRekeyConfirmedRecordArtifact._fromJson(
        json,
        common,
      ),
      _attachmentRequestKind =>
        E2eeDataRekeyPendingAttachmentArtifact._fromJson(json, common),
      _attachmentConfirmedKind =>
        E2eeDataRekeyConfirmedAttachmentArtifact._fromJson(json, common),
      _ => throw const FormatException('data-rekey artifact 类型无效'),
    };
  }
}

final class E2eeDataRekeyFinalizeArtifact {
  factory E2eeDataRekeyFinalizeArtifact({
    required E2eeDataRekeyArtifactBinding binding,
    required CloudSyncDataRekeyFinalizeRequest request,
  }) {
    _requireLeaseBinding(binding, request.activeLease);
    if (request.proof.issuerDeviceId != binding.issuerDeviceId) {
      throw const FormatException('data-rekey finalize 请求未绑定 issuer');
    }
    return E2eeDataRekeyFinalizeArtifact._(binding: binding, request: request);
  }

  const E2eeDataRekeyFinalizeArtifact._({
    required this.binding,
    required this.request,
  });

  factory E2eeDataRekeyFinalizeArtifact.decode(
    Uint8List bytes, {
    required E2eeDataRekeyArtifactBinding expectedBinding,
  }) {
    final json = _decodeArtifactJson(bytes);
    _requireArtifactExactKeys(json, _finalizeRequestKeys);
    if (_requireArtifactString(json, 'kind') != _finalizeRequestKind) {
      throw const FormatException('data-rekey finalize artifact 类型无效');
    }
    final common = _decodeCommon(json, expectedBinding: expectedBinding);
    final attachmentId = _requireNullableArtifactString(
      json,
      'sourceAttachmentIdEnd',
    );
    final attachmentUploadId = _requireNullableArtifactString(
      json,
      'sourceAttachmentUploadIdEnd',
    );
    if ((attachmentId == null) != (attachmentUploadId == null)) {
      throw const FormatException('data-rekey finalize 附件游标不完整');
    }
    final attachmentCursor = attachmentId == null
        ? null
        : CloudSyncDataRekeyAttachmentCursor(
            attachmentId: attachmentId,
            uploadId: attachmentUploadId!,
          );
    return E2eeDataRekeyFinalizeArtifact(
      binding: common.binding,
      request: CloudSyncDataRekeyFinalizeRequest(
        activeLease: common.activeLease,
        mutationId: common.mutationId,
        proof: CloudSyncDataRekeyFinalizeProof(
          issuerDeviceId: common.binding.issuerDeviceId,
          sourceSnapshotRoot: _decodeArtifactBytes(
            json,
            'sourceSnapshotRoot',
            exactLength: 32,
          ),
          sourceRecordCount: _requireArtifactInt(json, 'sourceRecordCount'),
          sourceAttachmentCount: _requireArtifactInt(
            json,
            'sourceAttachmentCount',
          ),
          sourceMaximumChangeSeq: _requireArtifactInt(
            json,
            'sourceMaximumChangeSeq',
          ),
          sourceRecordCursorEnd: _requireNullableArtifactString(
            json,
            'sourceRecordCursorEnd',
          ),
          sourceAttachmentCursorEnd: attachmentCursor,
          membershipGeneration: _requireArtifactInt(
            json,
            'membershipGeneration',
          ),
          membershipManifestDigest: _decodeArtifactBytes(
            json,
            'membershipManifestDigest',
            exactLength: 32,
          ),
          stagedRecordCount: _requireArtifactInt(json, 'stagedRecordCount'),
          stagedAttachmentCount: _requireArtifactInt(
            json,
            'stagedAttachmentCount',
          ),
          stagedCiphertextSetDigest: _decodeArtifactBytes(
            json,
            'stagedCiphertextSetDigest',
            exactLength: 32,
          ),
          signature: _decodeArtifactBytes(json, 'signature', exactLength: 64),
        ),
      ),
    );
  }

  final E2eeDataRekeyArtifactBinding binding;
  final CloudSyncDataRekeyFinalizeRequest request;

  String get artifactId => request.mutationId;

  Uint8List encode() {
    final proof = request.proof;
    final attachmentCursor = proof.sourceAttachmentCursorEnd;
    return _encodeArtifact(<String, Object?>{
      ..._commonJson(
        kind: _finalizeRequestKind,
        binding: binding,
        activeLease: request.activeLease,
        mutationId: request.mutationId,
      ),
      'sourceSnapshotRoot': _encodeArtifactBytes(proof.sourceSnapshotRoot),
      'sourceRecordCount': proof.sourceRecordCount,
      'sourceAttachmentCount': proof.sourceAttachmentCount,
      'sourceMaximumChangeSeq': proof.sourceMaximumChangeSeq,
      'sourceRecordCursorEnd': proof.sourceRecordCursorEnd,
      'sourceAttachmentIdEnd': attachmentCursor?.attachmentId,
      'sourceAttachmentUploadIdEnd': attachmentCursor?.uploadId,
      'membershipGeneration': proof.membershipGeneration,
      'membershipManifestDigest': _encodeArtifactBytes(
        proof.membershipManifestDigest,
      ),
      'stagedRecordCount': proof.stagedRecordCount,
      'stagedAttachmentCount': proof.stagedAttachmentCount,
      'stagedCiphertextSetDigest': _encodeArtifactBytes(
        proof.stagedCiphertextSetDigest,
      ),
      'signature': _encodeArtifactBytes(proof.signature),
    });
  }
}

final class E2eeDataRekeyPendingRecordArtifact
    extends E2eeDataRekeyStageArtifact {
  factory E2eeDataRekeyPendingRecordArtifact({
    required E2eeDataRekeyArtifactBinding binding,
    required CloudSyncDataRekeyActiveLease activeLease,
    required String mutationId,
    required String sourceRecordId,
    required String targetRecordId,
    required int sourceRevision,
    required Uint8List ciphertext,
  }) {
    _requireLeaseBinding(binding, activeLease);
    final request = CloudSyncDataRekeyRecordStageRequest(
      activeLease: activeLease,
      mutationId: mutationId,
      sourceRecordId: sourceRecordId,
      targetRecordId: targetRecordId,
      sourceRevision: sourceRevision,
      ciphertext: ciphertext,
    );
    return E2eeDataRekeyPendingRecordArtifact._(
      binding: binding,
      request: request,
    );
  }

  E2eeDataRekeyPendingRecordArtifact._({
    required super.binding,
    required this.request,
  }) : super(activeLease: request.activeLease, mutationId: request.mutationId);

  factory E2eeDataRekeyPendingRecordArtifact._fromJson(
    CloudSyncJsonMap json,
    _DecodedArtifactCommon common,
  ) {
    _requireArtifactExactKeys(json, _recordRequestKeys);
    return E2eeDataRekeyPendingRecordArtifact(
      binding: common.binding,
      activeLease: common.activeLease,
      mutationId: common.mutationId,
      sourceRecordId: _requireArtifactString(json, 'sourceRecordId'),
      targetRecordId: _requireArtifactString(json, 'targetRecordId'),
      sourceRevision: _requireArtifactInt(json, 'sourceRevision'),
      ciphertext: _decodeArtifactBytes(
        json,
        'ciphertext',
        maximumLength: 1048576,
      ),
    );
  }

  final CloudSyncDataRekeyRecordStageRequest request;

  E2eeDataRekeyConfirmedRecordArtifact confirm(
    CloudSyncDataRekeyRecordStageResult receipt,
  ) {
    if (receipt.operationId != binding.operation.operationId ||
        receipt.mutationId != request.mutationId ||
        receipt.sourceRecordId != request.sourceRecordId ||
        receipt.targetRecordId != request.targetRecordId ||
        receipt.leaseVersion != activeLease.leaseVersion) {
      throw const FormatException('data-rekey 记录回执未绑定缓存请求');
    }
    return E2eeDataRekeyConfirmedRecordArtifact._(
      binding: binding,
      activeLease: activeLease,
      mutationId: mutationId,
      digestItem: E2eeDataRekeyStagedRecordDigestItem(
        sourceRecordId: request.sourceRecordId,
        targetRecordId: request.targetRecordId,
        sourceRevision: request.sourceRevision,
        targetKeyEpoch: binding.operation.targetKeyEpoch,
        envelopeVersion: request.envelopeVersion,
        ciphertextBytes: request.ciphertext.length,
        ciphertextDigest: digestE2eeDataRekeyCiphertext(request.ciphertext),
      ),
    );
  }

  @override
  Uint8List encode() {
    return _encodeArtifact(<String, Object?>{
      ..._commonJson(
        kind: _recordRequestKind,
        binding: binding,
        activeLease: activeLease,
        mutationId: mutationId,
      ),
      'sourceRecordId': request.sourceRecordId,
      'targetRecordId': request.targetRecordId,
      'sourceRevision': request.sourceRevision,
      'ciphertext': _encodeArtifactBytes(request.ciphertext),
    });
  }
}

final class E2eeDataRekeyConfirmedRecordArtifact
    extends E2eeDataRekeyStageArtifact {
  E2eeDataRekeyConfirmedRecordArtifact._({
    required super.binding,
    required super.activeLease,
    required super.mutationId,
    required this.digestItem,
  });

  factory E2eeDataRekeyConfirmedRecordArtifact._fromJson(
    CloudSyncJsonMap json,
    _DecodedArtifactCommon common,
  ) {
    _requireArtifactExactKeys(json, _recordConfirmedKeys);
    final digestItem = E2eeDataRekeyStagedRecordDigestItem(
      sourceRecordId: _requireArtifactString(json, 'sourceRecordId'),
      targetRecordId: _requireArtifactString(json, 'targetRecordId'),
      sourceRevision: _requireArtifactInt(json, 'sourceRevision'),
      targetKeyEpoch: _requireArtifactInt(json, 'targetKeyEpoch'),
      envelopeVersion: _requireArtifactInt(json, 'envelopeVersion'),
      ciphertextBytes: _requireArtifactInt(json, 'ciphertextBytes'),
      ciphertextDigest: _decodeArtifactBytes(
        json,
        'ciphertextDigest',
        exactLength: 32,
      ),
    );
    if (digestItem.targetKeyEpoch != common.binding.operation.targetKeyEpoch ||
        digestItem.envelopeVersion != 1) {
      throw const FormatException('data-rekey 记录确认未绑定目标代次');
    }
    return E2eeDataRekeyConfirmedRecordArtifact._(
      binding: common.binding,
      activeLease: common.activeLease,
      mutationId: common.mutationId,
      digestItem: digestItem,
    );
  }

  final E2eeDataRekeyStagedRecordDigestItem digestItem;

  @override
  Uint8List encode() {
    return _encodeArtifact(<String, Object?>{
      ..._commonJson(
        kind: _recordConfirmedKind,
        binding: binding,
        activeLease: activeLease,
        mutationId: mutationId,
      ),
      'sourceRecordId': digestItem.sourceRecordId,
      'targetRecordId': digestItem.targetRecordId,
      'sourceRevision': digestItem.sourceRevision,
      'targetKeyEpoch': digestItem.targetKeyEpoch,
      'envelopeVersion': digestItem.envelopeVersion,
      'ciphertextBytes': digestItem.ciphertextBytes,
      'ciphertextDigest': _encodeArtifactBytes(digestItem.ciphertextDigest),
    });
  }
}

final class E2eeDataRekeyPendingAttachmentArtifact
    extends E2eeDataRekeyStageArtifact {
  factory E2eeDataRekeyPendingAttachmentArtifact({
    required E2eeDataRekeyArtifactBinding binding,
    required CloudSyncDataRekeyActiveLease activeLease,
    required String mutationId,
    required String attachmentId,
    required String uploadId,
    required int sourceManifestRevision,
    required Uint8List manifestCiphertext,
  }) {
    _requireLeaseBinding(binding, activeLease);
    final request = CloudSyncDataRekeyAttachmentStageRequest(
      activeLease: activeLease,
      mutationId: mutationId,
      attachmentId: attachmentId,
      uploadId: uploadId,
      sourceManifestRevision: sourceManifestRevision,
      manifestCiphertext: manifestCiphertext,
    );
    return E2eeDataRekeyPendingAttachmentArtifact._(
      binding: binding,
      request: request,
    );
  }

  E2eeDataRekeyPendingAttachmentArtifact._({
    required super.binding,
    required this.request,
  }) : super(activeLease: request.activeLease, mutationId: request.mutationId);

  factory E2eeDataRekeyPendingAttachmentArtifact._fromJson(
    CloudSyncJsonMap json,
    _DecodedArtifactCommon common,
  ) {
    _requireArtifactExactKeys(json, _attachmentRequestKeys);
    return E2eeDataRekeyPendingAttachmentArtifact(
      binding: common.binding,
      activeLease: common.activeLease,
      mutationId: common.mutationId,
      attachmentId: _requireArtifactString(json, 'attachmentId'),
      uploadId: _requireArtifactString(json, 'uploadId'),
      sourceManifestRevision: _requireArtifactInt(
        json,
        'sourceManifestRevision',
      ),
      manifestCiphertext: _decodeArtifactBytes(
        json,
        'manifestCiphertext',
        maximumLength: 1048576,
      ),
    );
  }

  final CloudSyncDataRekeyAttachmentStageRequest request;

  E2eeDataRekeyConfirmedAttachmentArtifact confirm(
    CloudSyncDataRekeyAttachmentStageResult receipt,
  ) {
    if (receipt.operationId != binding.operation.operationId ||
        receipt.mutationId != request.mutationId ||
        receipt.attachmentId != request.attachmentId ||
        receipt.uploadId != request.uploadId ||
        receipt.manifestRevision != request.manifestRevision ||
        receipt.leaseVersion != activeLease.leaseVersion) {
      throw const FormatException('data-rekey 附件回执未绑定缓存请求');
    }
    return E2eeDataRekeyConfirmedAttachmentArtifact._(
      binding: binding,
      activeLease: activeLease,
      mutationId: mutationId,
      digestItem: E2eeDataRekeyStagedAttachmentDigestItem(
        attachmentId: request.attachmentId,
        uploadId: request.uploadId,
        sourceManifestRevision: request.sourceManifestRevision,
        manifestRevision: request.manifestRevision,
        manifestKeyEpoch: request.manifestKeyEpoch,
        manifestCiphertextBytes: request.manifestCiphertext.length,
        manifestCiphertextDigest: digestE2eeDataRekeyCiphertext(
          request.manifestCiphertext,
        ),
      ),
    );
  }

  @override
  Uint8List encode() {
    return _encodeArtifact(<String, Object?>{
      ..._commonJson(
        kind: _attachmentRequestKind,
        binding: binding,
        activeLease: activeLease,
        mutationId: mutationId,
      ),
      'attachmentId': request.attachmentId,
      'uploadId': request.uploadId,
      'sourceManifestRevision': request.sourceManifestRevision,
      'manifestCiphertext': _encodeArtifactBytes(request.manifestCiphertext),
    });
  }
}

final class E2eeDataRekeyConfirmedAttachmentArtifact
    extends E2eeDataRekeyStageArtifact {
  E2eeDataRekeyConfirmedAttachmentArtifact._({
    required super.binding,
    required super.activeLease,
    required super.mutationId,
    required this.digestItem,
  });

  factory E2eeDataRekeyConfirmedAttachmentArtifact._fromJson(
    CloudSyncJsonMap json,
    _DecodedArtifactCommon common,
  ) {
    _requireArtifactExactKeys(json, _attachmentConfirmedKeys);
    final digestItem = E2eeDataRekeyStagedAttachmentDigestItem(
      attachmentId: _requireArtifactString(json, 'attachmentId'),
      uploadId: _requireArtifactString(json, 'uploadId'),
      sourceManifestRevision: _requireArtifactInt(
        json,
        'sourceManifestRevision',
      ),
      manifestRevision: _requireArtifactInt(json, 'manifestRevision'),
      manifestKeyEpoch: _requireArtifactInt(json, 'manifestKeyEpoch'),
      manifestCiphertextBytes: _requireArtifactInt(
        json,
        'manifestCiphertextBytes',
      ),
      manifestCiphertextDigest: _decodeArtifactBytes(
        json,
        'manifestCiphertextDigest',
        exactLength: 32,
      ),
    );
    if (digestItem.manifestKeyEpoch !=
            common.binding.operation.targetKeyEpoch ||
        digestItem.manifestRevision != digestItem.sourceManifestRevision + 1) {
      throw const FormatException('data-rekey 附件确认未绑定目标代次');
    }
    return E2eeDataRekeyConfirmedAttachmentArtifact._(
      binding: common.binding,
      activeLease: common.activeLease,
      mutationId: common.mutationId,
      digestItem: digestItem,
    );
  }

  final E2eeDataRekeyStagedAttachmentDigestItem digestItem;

  @override
  Uint8List encode() {
    return _encodeArtifact(<String, Object?>{
      ..._commonJson(
        kind: _attachmentConfirmedKind,
        binding: binding,
        activeLease: activeLease,
        mutationId: mutationId,
      ),
      'attachmentId': digestItem.attachmentId,
      'uploadId': digestItem.uploadId,
      'sourceManifestRevision': digestItem.sourceManifestRevision,
      'manifestRevision': digestItem.manifestRevision,
      'manifestKeyEpoch': digestItem.manifestKeyEpoch,
      'manifestCiphertextBytes': digestItem.manifestCiphertextBytes,
      'manifestCiphertextDigest': _encodeArtifactBytes(
        digestItem.manifestCiphertextDigest,
      ),
    });
  }
}

const _recordRequestKind = 'record-request-v1';
const _recordConfirmedKind = 'record-confirmed-v1';
const _attachmentRequestKind = 'attachment-request-v1';
const _attachmentConfirmedKind = 'attachment-confirmed-v1';
const _finalizeRequestKind = 'finalize-request-v1';

const _commonKeys = <String>{
  'formatVersion',
  'kind',
  'userId',
  'issuerDeviceId',
  'operationId',
  'sourceDataGeneration',
  'sourceKeyEpoch',
  'targetKeyEpoch',
  'leaseToken',
  'leaseVersion',
  'mutationId',
};
const _recordRequestKeys = <String>{
  ..._commonKeys,
  'sourceRecordId',
  'targetRecordId',
  'sourceRevision',
  'ciphertext',
};
const _recordConfirmedKeys = <String>{
  ..._commonKeys,
  'sourceRecordId',
  'targetRecordId',
  'sourceRevision',
  'envelopeVersion',
  'ciphertextBytes',
  'ciphertextDigest',
};
const _attachmentRequestKeys = <String>{
  ..._commonKeys,
  'attachmentId',
  'uploadId',
  'sourceManifestRevision',
  'manifestCiphertext',
};
const _attachmentConfirmedKeys = <String>{
  ..._commonKeys,
  'attachmentId',
  'uploadId',
  'sourceManifestRevision',
  'manifestRevision',
  'manifestKeyEpoch',
  'manifestCiphertextBytes',
  'manifestCiphertextDigest',
};
const _finalizeRequestKeys = <String>{
  ..._commonKeys,
  'sourceSnapshotRoot',
  'sourceRecordCount',
  'sourceAttachmentCount',
  'sourceMaximumChangeSeq',
  'sourceRecordCursorEnd',
  'sourceAttachmentIdEnd',
  'sourceAttachmentUploadIdEnd',
  'membershipGeneration',
  'membershipManifestDigest',
  'stagedRecordCount',
  'stagedAttachmentCount',
  'stagedCiphertextSetDigest',
  'signature',
};

final class _DecodedArtifactCommon {
  const _DecodedArtifactCommon({
    required this.binding,
    required this.activeLease,
    required this.mutationId,
  });

  final E2eeDataRekeyArtifactBinding binding;
  final CloudSyncDataRekeyActiveLease activeLease;
  final String mutationId;
}

_DecodedArtifactCommon _decodeCommon(
  CloudSyncJsonMap json, {
  required E2eeDataRekeyArtifactBinding expectedBinding,
}) {
  final operation = CloudSyncDataRekeyOperationScope(
    operationId: _requireArtifactString(json, 'operationId'),
    sourceDataGeneration: _requireArtifactInt(json, 'sourceDataGeneration'),
    sourceKeyEpoch: _requireArtifactInt(json, 'sourceKeyEpoch'),
    targetKeyEpoch: _requireArtifactInt(json, 'targetKeyEpoch'),
  );
  final binding = E2eeDataRekeyArtifactBinding(
    userId: _requireArtifactString(json, 'userId'),
    issuerDeviceId: _requireArtifactString(json, 'issuerDeviceId'),
    operation: operation,
  );
  if (binding != expectedBinding) {
    throw const FormatException('data-rekey artifact 账户或 operation 绑定不匹配');
  }
  final activeLease = CloudSyncDataRekeyActiveLease(
    operation: operation,
    leaseToken: _requireArtifactString(json, 'leaseToken'),
    leaseVersion: _requireArtifactInt(json, 'leaseVersion'),
  );
  return _DecodedArtifactCommon(
    binding: binding,
    activeLease: activeLease,
    mutationId: _requireArtifactUuid(
      _requireArtifactString(json, 'mutationId'),
      'mutationId',
    ),
  );
}

CloudSyncJsonMap _commonJson({
  required String kind,
  required E2eeDataRekeyArtifactBinding binding,
  required CloudSyncDataRekeyActiveLease activeLease,
  required String mutationId,
}) {
  _requireLeaseBinding(binding, activeLease);
  return <String, Object?>{
    'formatVersion': 1,
    'kind': kind,
    'userId': binding.userId,
    'issuerDeviceId': binding.issuerDeviceId,
    'operationId': binding.operation.operationId,
    'sourceDataGeneration': binding.operation.sourceDataGeneration,
    'sourceKeyEpoch': binding.operation.sourceKeyEpoch,
    'targetKeyEpoch': binding.operation.targetKeyEpoch,
    'leaseToken': activeLease.leaseToken,
    'leaseVersion': activeLease.leaseVersion,
    'mutationId': mutationId,
  };
}

void _requireLeaseBinding(
  E2eeDataRekeyArtifactBinding binding,
  CloudSyncDataRekeyActiveLease activeLease,
) {
  final expected = binding.operation;
  final actual = activeLease.operation;
  if (expected.operationId != actual.operationId ||
      expected.sourceDataGeneration != actual.sourceDataGeneration ||
      expected.sourceKeyEpoch != actual.sourceKeyEpoch ||
      expected.targetKeyEpoch != actual.targetKeyEpoch) {
    throw const FormatException('data-rekey artifact 租约未绑定 operation');
  }
}

CloudSyncJsonMap _decodeArtifactJson(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > e2eeDataRekeyArtifactMaximumBytes) {
    throw const FormatException('data-rekey artifact 长度无效');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  } on FormatException {
    rethrow;
  }
  if (decoded is! Map<Object?, Object?> ||
      decoded.keys.any((key) => key is! String)) {
    throw const FormatException('data-rekey artifact 必须为 JSON 对象');
  }
  final json = <String, Object?>{
    for (final entry in decoded.entries) entry.key! as String: entry.value,
  };
  final canonical = Uint8List.fromList(utf8.encode(jsonEncode(json)));
  if (!_sameArtifactBytes(canonical, bytes)) {
    throw const FormatException('data-rekey artifact JSON 编码不规范');
  }
  if (_requireArtifactInt(json, 'formatVersion') != 1) {
    throw const FormatException('data-rekey artifact 版本无效');
  }
  return json;
}

Uint8List _encodeArtifact(CloudSyncJsonMap json) {
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
  if (bytes.length > e2eeDataRekeyArtifactMaximumBytes) {
    throw const FormatException('data-rekey artifact 编码超过上限');
  }
  return bytes;
}

String _encodeArtifactBytes(Uint8List value) {
  return base64UrlEncode(value).replaceAll('=', '');
}

Uint8List _decodeArtifactBytes(
  CloudSyncJsonMap json,
  String key, {
  int? exactLength,
  int? maximumLength,
}) {
  final encoded = _requireArtifactString(json, key);
  if (!_canonicalBase64UrlPattern.hasMatch(encoded)) {
    throw FormatException('$key 不是规范 base64url');
  }
  final padding = List<String>.filled((4 - encoded.length % 4) % 4, '=').join();
  final Uint8List value;
  try {
    value = Uint8List.fromList(base64Url.decode('$encoded$padding'));
  } on FormatException {
    throw FormatException('$key 不是规范 base64url');
  }
  if (_encodeArtifactBytes(value) != encoded ||
      (exactLength != null && value.length != exactLength) ||
      (maximumLength != null &&
          (value.isEmpty || value.length > maximumLength))) {
    throw FormatException('$key 长度或编码无效');
  }
  return value;
}

void _requireArtifactExactKeys(CloudSyncJsonMap json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('data-rekey artifact 字段集合无效');
  }
}

String _requireArtifactString(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key 必须为非空字符串');
  }
  return value;
}

int _requireArtifactInt(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key 必须为整数');
  }
  return value;
}

String? _requireNullableArtifactString(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('$key 必须为非空字符串或 null');
  }
  return value;
}

String _requireArtifactUuid(String value, String name) {
  if (!_artifactUuidPattern.hasMatch(value)) {
    throw FormatException('$name 必须为规范 UUIDv4');
  }
  return value;
}

bool _sameArtifactBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
