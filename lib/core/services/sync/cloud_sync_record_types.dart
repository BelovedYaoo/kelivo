import 'e2ee_account_record_cipher.dart';
import 'e2ee_account_record_state.dart';

String _requireMatchingOperationId(
  String mutationId,
  E2eeSealedAccountRecordState state,
) {
  if (mutationId != state.operationId) {
    throw ArgumentError.value(
      mutationId,
      'mutationId',
      '必须与密文状态的 operationId 一致',
    );
  }
  return mutationId;
}

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
    required String mutationId,
    required super.expectedRevision,
    required E2eeSealedAccountRecordState state,
  }) : state = state,
       super(
         mutationId: _requireMatchingOperationId(mutationId, state),
         recordId: state.record.recordId,
       );

  final E2eeSealedAccountRecordState state;
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
