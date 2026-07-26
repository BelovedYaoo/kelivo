import 'e2ee_account_record_cipher.dart';

sealed class CloudSyncRecordMutation {
  const CloudSyncRecordMutation({
    required this.mutationId,
    required this.recordId,
    required this.expectedRevision,
  });

  final String mutationId;
  final E2eeAccountRecordId recordId;
  final int expectedRevision;
}

final class CloudSyncPutRecordMutation extends CloudSyncRecordMutation {
  CloudSyncPutRecordMutation({
    required super.mutationId,
    required super.expectedRevision,
    required this.record,
  }) : super(recordId: record.recordId);

  final E2eeSealedAccountRecordEnvelope record;
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
  final E2eeUntrustedAccountRecordId recordId;
  final int revision;
  final DateTime updatedAt;
  final String? updatedByDeviceId;
}

final class CloudSyncPutRecordChange extends CloudSyncRecordChange {
  CloudSyncPutRecordChange({
    required super.changeSeq,
    required super.revision,
    required super.updatedAt,
    required super.updatedByDeviceId,
    required this.record,
  }) : super(recordId: record.recordId);

  final E2eeUntrustedAccountRecordEnvelope record;
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

  final E2eeUntrustedAccountRecordId recordId;
  final int revision;
  final DateTime updatedAt;
  final String? updatedByDeviceId;
  final int lastChangeSeq;
}

final class CloudSyncActiveRecord extends CloudSyncRecordState {
  CloudSyncActiveRecord({
    required super.revision,
    required super.updatedAt,
    required super.updatedByDeviceId,
    required super.lastChangeSeq,
    required this.record,
  }) : super(recordId: record.recordId);

  final E2eeUntrustedAccountRecordEnvelope record;
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
