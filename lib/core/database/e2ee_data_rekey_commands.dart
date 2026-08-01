part of 'chat_database_repository.dart';

const _dataRekeyMaximumInt32 = 2147483647;
const _dataRekeyMaximumUint32 = 4294967295;

enum E2eeDataRekeyJournalPhase {
  claimPending('claim-pending'),
  leased('leased'),
  scanning('scanning'),
  staging('staging'),
  finalizing('finalizing');

  const E2eeDataRekeyJournalPhase(this.wireValue);

  final String wireValue;

  static E2eeDataRekeyJournalPhase fromWire(String value) => switch (value) {
    'claim-pending' => claimPending,
    'leased' => leased,
    'scanning' => scanning,
    'staging' => staging,
    'finalizing' => finalizing,
    _ => throw StateError('data_rekey_journal_phase_invalid'),
  };
}

final class E2eeDataRekeyOperationBinding {
  factory E2eeDataRekeyOperationBinding({
    required String userId,
    required String issuerDeviceId,
    required String operationId,
    required int sourceDataGeneration,
    required int sourceKeyEpoch,
    required int targetKeyEpoch,
    required int sourceRecordCount,
    required int sourceAttachmentCount,
    required int sourceMaximumChangeSeq,
    required String? sourceRecordCursorEnd,
    required String? sourceAttachmentIdEnd,
    required String? sourceAttachmentUploadIdEnd,
    required int membershipGeneration,
    required Uint8List membershipManifestDigest,
  }) {
    final checkedSourceKeyEpoch = _requireDataRekeyInt(
      sourceKeyEpoch,
      'sourceKeyEpoch',
      minimum: 1,
      maximum: _dataRekeyMaximumUint32 - 1,
    );
    final checkedTargetKeyEpoch = _requireDataRekeyInt(
      targetKeyEpoch,
      'targetKeyEpoch',
      minimum: 2,
      maximum: _dataRekeyMaximumUint32,
    );
    if (checkedTargetKeyEpoch != checkedSourceKeyEpoch + 1) {
      throw const FormatException('data-rekey 目标密钥世代不连续');
    }
    final checkedRecordCount = _requireDataRekeyInt(
      sourceRecordCount,
      'sourceRecordCount',
      minimum: 0,
      maximum: _dataRekeyMaximumInt32,
    );
    final checkedAttachmentCount = _requireDataRekeyInt(
      sourceAttachmentCount,
      'sourceAttachmentCount',
      minimum: 0,
      maximum: _dataRekeyMaximumInt32,
    );
    final checkedRecordCursor = _requireDataRekeyCountCursor(
      count: checkedRecordCount,
      value: sourceRecordCursorEnd,
      name: 'sourceRecordCursorEnd',
    );
    final checkedAttachmentId = _requireDataRekeyCountCursor(
      count: checkedAttachmentCount,
      value: sourceAttachmentIdEnd,
      name: 'sourceAttachmentIdEnd',
    );
    final checkedAttachmentUploadId = _requireDataRekeyCountCursor(
      count: checkedAttachmentCount,
      value: sourceAttachmentUploadIdEnd,
      name: 'sourceAttachmentUploadIdEnd',
    );
    if (membershipManifestDigest.length != 32) {
      throw const FormatException('membershipManifestDigest 长度无效');
    }
    return E2eeDataRekeyOperationBinding._(
      userId: _requireCanonicalUuidV4(userId, 'userId'),
      issuerDeviceId: _requireCanonicalUuidV4(issuerDeviceId, 'issuerDeviceId'),
      operationId: _requireCanonicalUuidV4(operationId, 'operationId'),
      sourceDataGeneration: _requireDataRekeyInt(
        sourceDataGeneration,
        'sourceDataGeneration',
        minimum: 1,
        maximum: _dataRekeyMaximumInt32,
      ),
      sourceKeyEpoch: checkedSourceKeyEpoch,
      targetKeyEpoch: checkedTargetKeyEpoch,
      sourceRecordCount: checkedRecordCount,
      sourceAttachmentCount: checkedAttachmentCount,
      sourceMaximumChangeSeq: _requireDataRekeyInt(
        sourceMaximumChangeSeq,
        'sourceMaximumChangeSeq',
        minimum: 0,
        maximum: _maxPositiveInt63,
      ),
      sourceRecordCursorEnd: checkedRecordCursor,
      sourceAttachmentIdEnd: checkedAttachmentId,
      sourceAttachmentUploadIdEnd: checkedAttachmentUploadId,
      membershipGeneration: _requireDataRekeyInt(
        membershipGeneration,
        'membershipGeneration',
        minimum: 1,
        maximum: _dataRekeyMaximumInt32,
      ),
      membershipManifestDigest: _copyBytes(membershipManifestDigest),
    );
  }

  const E2eeDataRekeyOperationBinding._({
    required this.userId,
    required this.issuerDeviceId,
    required this.operationId,
    required this.sourceDataGeneration,
    required this.sourceKeyEpoch,
    required this.targetKeyEpoch,
    required this.sourceRecordCount,
    required this.sourceAttachmentCount,
    required this.sourceMaximumChangeSeq,
    required this.sourceRecordCursorEnd,
    required this.sourceAttachmentIdEnd,
    required this.sourceAttachmentUploadIdEnd,
    required this.membershipGeneration,
    required this.membershipManifestDigest,
  });

  final String userId;
  final String issuerDeviceId;
  final String operationId;
  final int sourceDataGeneration;
  final int sourceKeyEpoch;
  final int targetKeyEpoch;
  final int sourceRecordCount;
  final int sourceAttachmentCount;
  final int sourceMaximumChangeSeq;
  final String? sourceRecordCursorEnd;
  final String? sourceAttachmentIdEnd;
  final String? sourceAttachmentUploadIdEnd;
  final int membershipGeneration;
  final Uint8List membershipManifestDigest;

  @override
  bool operator ==(Object other) =>
      other is E2eeDataRekeyOperationBinding &&
      userId == other.userId &&
      issuerDeviceId == other.issuerDeviceId &&
      operationId == other.operationId &&
      sourceDataGeneration == other.sourceDataGeneration &&
      sourceKeyEpoch == other.sourceKeyEpoch &&
      targetKeyEpoch == other.targetKeyEpoch &&
      sourceRecordCount == other.sourceRecordCount &&
      sourceAttachmentCount == other.sourceAttachmentCount &&
      sourceMaximumChangeSeq == other.sourceMaximumChangeSeq &&
      sourceRecordCursorEnd == other.sourceRecordCursorEnd &&
      sourceAttachmentIdEnd == other.sourceAttachmentIdEnd &&
      sourceAttachmentUploadIdEnd == other.sourceAttachmentUploadIdEnd &&
      membershipGeneration == other.membershipGeneration &&
      _sameBytes(membershipManifestDigest, other.membershipManifestDigest);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    userId,
    issuerDeviceId,
    operationId,
    sourceDataGeneration,
    sourceKeyEpoch,
    targetKeyEpoch,
    sourceRecordCount,
    sourceAttachmentCount,
    sourceMaximumChangeSeq,
    sourceRecordCursorEnd,
    sourceAttachmentIdEnd,
    sourceAttachmentUploadIdEnd,
    membershipGeneration,
    Object.hashAll(membershipManifestDigest),
  ]);
}

final class E2eeDataRekeyJournalState {
  const E2eeDataRekeyJournalState._({
    required this.binding,
    required this.phase,
    required this.leaseToken,
    required this.leaseMutationId,
    required this.leaseVersion,
    required this.leaseExpiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final E2eeDataRekeyOperationBinding binding;
  final E2eeDataRekeyJournalPhase phase;
  final String leaseToken;
  final String leaseMutationId;
  final int? leaseVersion;
  final DateTime? leaseExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class E2eeDataRekeyCommands {
  const E2eeDataRekeyCommands._(this._database);

  final AppDatabase _database;

  Future<E2eeDataRekeyJournalState> ensureClaimIntent({
    required E2eeDataRekeyOperationBinding binding,
    required DateTime now,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    return _database.transaction(() async {
      final table = _database.e2eeDataRekeyOperationRows;
      final existing = await _database.select(table).getSingleOrNull();
      if (existing != null) {
        final state = _dataRekeyJournalStateFromRow(existing);
        if (state.binding.operationId == binding.operationId) {
          if (state.binding != binding) {
            throw StateError('data_rekey_operation_binding_changed');
          }
          return state;
        }
        throw StateError('data_rekey_operation_in_progress');
      }

      final leaseToken = const Uuid().v4();
      var leaseMutationId = const Uuid().v4();
      while (leaseMutationId == leaseToken) {
        leaseMutationId = const Uuid().v4();
      }
      await _database
          .into(table)
          .insert(
            E2eeDataRekeyOperationRowsCompanion.insert(
              userId: binding.userId,
              issuerDeviceId: binding.issuerDeviceId,
              operationId: binding.operationId,
              sourceDataGeneration: binding.sourceDataGeneration,
              sourceKeyEpoch: binding.sourceKeyEpoch,
              targetKeyEpoch: binding.targetKeyEpoch,
              sourceRecordCount: binding.sourceRecordCount,
              sourceAttachmentCount: binding.sourceAttachmentCount,
              sourceMaximumChangeSeq: binding.sourceMaximumChangeSeq,
              sourceRecordCursorEnd: Value(binding.sourceRecordCursorEnd),
              sourceAttachmentIdEnd: Value(binding.sourceAttachmentIdEnd),
              sourceAttachmentUploadIdEnd: Value(
                binding.sourceAttachmentUploadIdEnd,
              ),
              membershipGeneration: binding.membershipGeneration,
              membershipManifestDigest: binding.membershipManifestDigest,
              phase: E2eeDataRekeyJournalPhase.claimPending.wireValue,
              leaseToken: leaseToken,
              leaseMutationId: leaseMutationId,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      return _dataRekeyJournalStateFromRow(
        await _database.select(table).getSingle(),
      );
    });
  }
}

E2eeDataRekeyJournalState _dataRekeyJournalStateFromRow(
  E2eeDataRekeyOperationRow row,
) {
  final phase = E2eeDataRekeyJournalPhase.fromWire(row.phase);
  if ((phase == E2eeDataRekeyJournalPhase.claimPending) !=
      (row.leaseVersion == null && row.leaseExpiresAt == null)) {
    throw StateError('data_rekey_lease_state_invalid');
  }
  return E2eeDataRekeyJournalState._(
    binding: E2eeDataRekeyOperationBinding(
      userId: row.userId,
      issuerDeviceId: row.issuerDeviceId,
      operationId: row.operationId,
      sourceDataGeneration: row.sourceDataGeneration,
      sourceKeyEpoch: row.sourceKeyEpoch,
      targetKeyEpoch: row.targetKeyEpoch,
      sourceRecordCount: row.sourceRecordCount,
      sourceAttachmentCount: row.sourceAttachmentCount,
      sourceMaximumChangeSeq: row.sourceMaximumChangeSeq,
      sourceRecordCursorEnd: row.sourceRecordCursorEnd,
      sourceAttachmentIdEnd: row.sourceAttachmentIdEnd,
      sourceAttachmentUploadIdEnd: row.sourceAttachmentUploadIdEnd,
      membershipGeneration: row.membershipGeneration,
      membershipManifestDigest: row.membershipManifestDigest,
    ),
    phase: phase,
    leaseToken: _requireCanonicalUuidV4(row.leaseToken, 'leaseToken'),
    leaseMutationId: _requireCanonicalUuidV4(
      row.leaseMutationId,
      'leaseMutationId',
    ),
    leaseVersion: row.leaseVersion,
    leaseExpiresAt: row.leaseExpiresAt?.toUtc(),
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
  );
}

int _requireDataRekeyInt(
  int value,
  String name, {
  required int minimum,
  required int maximum,
}) {
  if (value < minimum || value > maximum) {
    throw FormatException('$name 超出有效范围');
  }
  return value;
}

String? _requireDataRekeyCountCursor({
  required int count,
  required String? value,
  required String name,
}) {
  if ((count == 0) != (value == null)) {
    throw FormatException('$name 与数量不一致');
  }
  return value == null ? null : _requireCanonicalUuidV4(value, name);
}
