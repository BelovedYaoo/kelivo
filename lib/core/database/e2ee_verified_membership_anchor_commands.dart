part of '../services/sync/e2ee_account_trust_manifest.dart';

const _maximumAnchorTransitionVersion = 0x7fffffffffffffff;

final class E2eeLocallyVerifiedMembershipAnchor {
  const E2eeLocallyVerifiedMembershipAnchor._({
    required this._databaseIdentity,
    required this.membership,
    required this.transitionVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  final Object _databaseIdentity;
  final E2eeVerifiedMembership membership;
  final int transitionVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class E2eeVerifiedMembershipAnchorConflict implements Exception {
  const E2eeVerifiedMembershipAnchorConflict();

  @override
  String toString() => 'E2eeVerifiedMembershipAnchorConflict()';
}

final class E2eeVerifiedMembershipAnchorStale implements Exception {
  const E2eeVerifiedMembershipAnchorStale();

  @override
  String toString() => 'E2eeVerifiedMembershipAnchorStale()';
}

final class E2eeVerifiedMembershipAnchorCommands {
  factory E2eeVerifiedMembershipAnchorCommands.forDatabase(
    AppDatabase database,
  ) => E2eeVerifiedMembershipAnchorCommands._(database);

  E2eeVerifiedMembershipAnchorCommands._(this._database);

  final AppDatabase _database;
  final E2eeAccountTrustManifestModule _manifestModule =
      const E2eeAccountTrustManifestModule();

  Future<E2eeLocallyVerifiedMembershipAnchor?> readVerified({
    required String accountUserId,
    required KelivoAccountRootKeyHandle ark,
  }) async {
    final userId = _canonicalUuidV4(accountUserId, 'accountUserId');
    final row = await _row(userId);
    if (row == null) return null;
    try {
      final membership = await _manifestModule._verifyPersistedAnchor(
        ark: ark,
        userId: row.accountUserId,
        securityGeneration: row.securityGeneration,
        keyEpoch: row.keyEpoch,
        persistedManifest: row.membershipManifest,
        persistedManifestDigest: row.membershipManifestDigest,
      );
      return _anchorFromRow(row, membership);
    } finally {
      _clearRowBytes(row);
    }
  }

  Future<E2eeLocallyVerifiedMembershipAnchor> install({
    required E2eeVerifiedMembership membership,
    required DateTime now,
  }) async {
    final timestamp = _requireAnchorStorageTime(now, 'now');
    final manifest = Uint8List.fromList(membership.manifest);
    final digest = Uint8List.fromList(membership.digest);
    try {
      return await _database.transaction(() async {
        // 首条语句直接取得写快照，双连接竞争不会从陈旧读快照升级写事务。
        await _database
            .into(_database.e2eeVerifiedMembershipAnchorRows)
            .insert(
              E2eeVerifiedMembershipAnchorRowsCompanion.insert(
                accountUserId: membership.userId,
                membershipManifest: manifest,
                membershipManifestDigest: digest,
                securityGeneration: membership.securityGeneration,
                keyEpoch: membership.keyEpoch,
                transitionVersion: 1,
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
              mode: InsertMode.insertOrIgnore,
            );

        final installed =
            await _row(membership.userId) ?? (throw StateError('成员清单锚点安装后丢失'));
        try {
          if (!_rowMatchesMembership(installed, membership)) {
            throw const E2eeVerifiedMembershipAnchorConflict();
          }
          return _anchorFromRow(installed, membership);
        } finally {
          _clearRowBytes(installed);
        }
      });
    } finally {
      manifest.fillRange(0, manifest.length, 0);
      digest.fillRange(0, digest.length, 0);
    }
  }

  Future<E2eeLocallyVerifiedMembershipAnchor> advance({
    required E2eeLocallyVerifiedMembershipAnchor expected,
    required E2eeVerifiedMembership next,
    required DateTime now,
  }) async {
    if (!identical(expected._databaseIdentity, _database)) {
      throw const E2eeVerifiedMembershipAnchorStale();
    }
    _requireSuccessor(expected.membership, next);
    final requestedTimestamp = _requireAnchorStorageTime(now, 'now');
    final expectedUpdatedAt = expected.updatedAt.toUtc();
    final timestamp = requestedTimestamp.isBefore(expectedUpdatedAt)
        ? expectedUpdatedAt
        : requestedTimestamp;
    final nextTransitionVersion = _nextAnchorTransitionVersion(
      expected.transitionVersion,
    );
    final manifest = Uint8List.fromList(next.manifest);
    final digest = Uint8List.fromList(next.digest);
    try {
      return await _database.transaction(() async {
        // UPDATE 必须是事务首条语句，确保竞争连接等待赢家提交后再判定重放或陈旧。
        final updated =
            await (_database.update(
                  _database.e2eeVerifiedMembershipAnchorRows,
                )..where(
                  (row) =>
                      row.accountUserId.equals(expected.membership.userId) &
                      row.securityGeneration.equals(
                        expected.membership.securityGeneration,
                      ) &
                      row.keyEpoch.equals(expected.membership.keyEpoch) &
                      row.transitionVersion.equals(expected.transitionVersion) &
                      row.membershipManifest.equals(
                        expected.membership.manifest,
                      ) &
                      row.membershipManifestDigest.equals(
                        expected.membership.digest,
                      ) &
                      row.createdAt.equals(
                        expected.createdAt.microsecondsSinceEpoch,
                      ) &
                      row.updatedAt.equals(
                        expected.updatedAt.microsecondsSinceEpoch,
                      ),
                ))
                .write(
                  E2eeVerifiedMembershipAnchorRowsCompanion(
                    membershipManifest: Value(manifest),
                    membershipManifestDigest: Value(digest),
                    securityGeneration: Value(next.securityGeneration),
                    keyEpoch: Value(next.keyEpoch),
                    transitionVersion: Value(nextTransitionVersion),
                    updatedAt: Value(timestamp),
                  ),
                );
        if (updated == 1) {
          return E2eeLocallyVerifiedMembershipAnchor._(
            databaseIdentity: _database,
            membership: next,
            transitionVersion: nextTransitionVersion,
            createdAt: expected.createdAt.toUtc(),
            updatedAt: timestamp,
          );
        }

        final current =
            await _row(expected.membership.userId) ??
            (throw const E2eeVerifiedMembershipAnchorStale());
        try {
          if (_rowMatchesReplay(
            current,
            expected,
            next,
            nextTransitionVersion,
          )) {
            return _anchorFromRow(current, next);
          }
          throw const E2eeVerifiedMembershipAnchorStale();
        } finally {
          _clearRowBytes(current);
        }
      });
    } finally {
      manifest.fillRange(0, manifest.length, 0);
      digest.fillRange(0, digest.length, 0);
    }
  }

  Future<E2eeVerifiedMembershipAnchorRow?> _row(String userId) {
    return (_database.select(
      _database.e2eeVerifiedMembershipAnchorRows,
    )..where((row) => row.accountUserId.equals(userId))).getSingleOrNull();
  }

  E2eeLocallyVerifiedMembershipAnchor _anchorFromRow(
    E2eeVerifiedMembershipAnchorRow row,
    E2eeVerifiedMembership membership,
  ) {
    return E2eeLocallyVerifiedMembershipAnchor._(
      databaseIdentity: _database,
      membership: membership,
      transitionVersion: row.transitionVersion,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}

void _requireSuccessor(
  E2eeVerifiedMembership previous,
  E2eeVerifiedMembership next,
) {
  if (next.userId != previous.userId ||
      next.securityGeneration != previous.securityGeneration + 1 ||
      !_sameBytes(next.previousDigest, previous.digest)) {
    throw const FormatException('成员清单后继与本地锚点不连续');
  }
  switch (next.operationKind) {
    case E2eeMembershipOperationKind.initialize:
      throw const FormatException('成员清单后继不能再次初始化');
    case E2eeMembershipOperationKind.addDevice:
      if (next.keyEpoch != previous.keyEpoch) {
        throw const FormatException('新增设备不得推进 ARK 代次');
      }
    case E2eeMembershipOperationKind.recoverResume:
      if (next.keyEpoch != previous.keyEpoch) {
        throw const FormatException('恢复接续不得推进 ARK 代次');
      }
    case E2eeMembershipOperationKind.revokeRotate:
      if (previous.keyEpoch >= _maximumUint32 ||
          next.keyEpoch != previous.keyEpoch + 1) {
        throw const FormatException('撤销设备必须精确推进一个 ARK 代次');
      }
    case E2eeMembershipOperationKind.recoverReplace:
      if (previous.keyEpoch >= _maximumUint32 ||
          next.keyEpoch != previous.keyEpoch + 1) {
        throw const FormatException('恢复替换必须精确推进一个 ARK 代次');
      }
  }
}

bool _rowMatchesReplay(
  E2eeVerifiedMembershipAnchorRow row,
  E2eeLocallyVerifiedMembershipAnchor expected,
  E2eeVerifiedMembership next,
  int nextTransitionVersion,
) {
  return row.transitionVersion == nextTransitionVersion &&
      row.createdAt.isAtSameMomentAs(expected.createdAt) &&
      !row.updatedAt.isBefore(expected.updatedAt) &&
      _rowMatchesMembership(row, next);
}

bool _rowMatchesMembership(
  E2eeVerifiedMembershipAnchorRow row,
  E2eeVerifiedMembership membership,
) {
  return row.accountUserId == membership.userId &&
      row.securityGeneration == membership.securityGeneration &&
      row.keyEpoch == membership.keyEpoch &&
      _sameBytes(row.membershipManifest, membership.manifest) &&
      _sameBytes(row.membershipManifestDigest, membership.digest);
}

int _nextAnchorTransitionVersion(int current) {
  if (current >= _maximumAnchorTransitionVersion) {
    throw StateError('成员清单锚点 transitionVersion 已耗尽');
  }
  return current + 1;
}

DateTime _requireAnchorStorageTime(DateTime value, String name) {
  final normalized = value.toUtc();
  if (normalized.microsecondsSinceEpoch < 0) {
    throw FormatException('$name 不得早于 Unix epoch');
  }
  return normalized;
}

void _clearRowBytes(E2eeVerifiedMembershipAnchorRow row) {
  row.membershipManifest.fillRange(0, row.membershipManifest.length, 0);
  row.membershipManifestDigest.fillRange(
    0,
    row.membershipManifestDigest.length,
    0,
  );
}
