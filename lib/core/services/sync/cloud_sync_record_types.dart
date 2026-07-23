sealed class CloudSyncRecordMutation {
  const CloudSyncRecordMutation({
    required this.mutationId,
    required this.recordId,
    required this.expectedRevision,
  });

  final String mutationId;
  final String recordId;
  final int expectedRevision;
}

final class CloudSyncPutRecordMutation extends CloudSyncRecordMutation {
  const CloudSyncPutRecordMutation({
    required super.mutationId,
    required super.recordId,
    required super.expectedRevision,
    required this.keyEpoch,
    required this.ciphertext,
  });

  static const envelopeVersion = 1;

  final int keyEpoch;
  final String ciphertext;
}

final class CloudSyncDeleteRecordMutation extends CloudSyncRecordMutation {
  const CloudSyncDeleteRecordMutation({
    required super.mutationId,
    required super.recordId,
    required super.expectedRevision,
  });
}

sealed class CloudSyncRecordMutationResult {
  const CloudSyncRecordMutationResult({required this.mutationId});

  final String mutationId;
}

final class CloudSyncAppliedMutationResult
    extends CloudSyncRecordMutationResult {
  const CloudSyncAppliedMutationResult({
    required super.mutationId,
    required this.revision,
    required this.changeSeq,
  });

  final int revision;
  final int changeSeq;
}

final class CloudSyncConflictMutationResult
    extends CloudSyncRecordMutationResult {
  const CloudSyncConflictMutationResult({
    required super.mutationId,
    required this.currentRevision,
  });

  final int? currentRevision;
}

final class CloudSyncRejectedMutationResult
    extends CloudSyncRecordMutationResult {
  const CloudSyncRejectedMutationResult({
    required super.mutationId,
    required this.errorCode,
  });

  final String errorCode;
}

sealed class CloudSyncRecordChange {
  const CloudSyncRecordChange({
    required this.changeSeq,
    required this.recordId,
    required this.revision,
    required this.updatedAt,
    required this.updatedByDeviceId,
  });

  final int changeSeq;
  final String recordId;
  final int revision;
  final DateTime updatedAt;
  final String? updatedByDeviceId;
}

final class CloudSyncPutRecordChange extends CloudSyncRecordChange {
  const CloudSyncPutRecordChange({
    required super.changeSeq,
    required super.recordId,
    required super.revision,
    required super.updatedAt,
    required super.updatedByDeviceId,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertext,
  });

  final int envelopeVersion;
  final int keyEpoch;
  final String ciphertext;
}

final class CloudSyncDeleteRecordChange extends CloudSyncRecordChange {
  const CloudSyncDeleteRecordChange({
    required super.changeSeq,
    required super.recordId,
    required super.revision,
    required super.updatedAt,
    required super.updatedByDeviceId,
    required this.deletedAt,
  });

  final DateTime deletedAt;
}

final class CloudSyncChangePage {
  const CloudSyncChangePage({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
    required this.resetRequired,
  });

  final List<CloudSyncRecordChange> changes;
  final String nextCursor;
  final bool hasMore;
  final bool resetRequired;
}

sealed class CloudSyncRecordState {
  const CloudSyncRecordState({
    required this.recordId,
    required this.revision,
    required this.updatedAt,
    required this.updatedByDeviceId,
    required this.lastChangeSeq,
  });

  final String recordId;
  final int revision;
  final DateTime updatedAt;
  final String? updatedByDeviceId;
  final int lastChangeSeq;
}

final class CloudSyncActiveRecord extends CloudSyncRecordState {
  const CloudSyncActiveRecord({
    required super.recordId,
    required super.revision,
    required super.updatedAt,
    required super.updatedByDeviceId,
    required super.lastChangeSeq,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertext,
  });

  final int envelopeVersion;
  final int keyEpoch;
  final String ciphertext;
}

final class CloudSyncDeletedRecord extends CloudSyncRecordState {
  const CloudSyncDeletedRecord({
    required super.recordId,
    required super.revision,
    required super.updatedAt,
    required super.updatedByDeviceId,
    required super.lastChangeSeq,
    required this.deletedAt,
  });

  final DateTime deletedAt;
}

final class CloudSyncSnapshotPage {
  const CloudSyncSnapshotPage({
    required this.records,
    required this.nextSnapshotCursor,
    required this.syncCursor,
    required this.hasMore,
  });

  final List<CloudSyncRecordState> records;
  final String? nextSnapshotCursor;
  final String? syncCursor;
  final bool hasMore;
}
