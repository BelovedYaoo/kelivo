import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../../database/chat_database_repository.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_record_types.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_record_cipher.dart';
import 'e2ee_account_record_state.dart';
import 'e2ee_sync_execution_budget.dart';
import 'sync_codec.dart';
import 'sync_write_executor.dart';

const _sealLeaseDuration = Duration(minutes: 2);
const _sendLeaseDuration = Duration(minutes: 5);
const _dirtyIntentScanLimit = 10;
const _localCiphertextAuthenticationFailure =
    'LOCAL_CIPHERTEXT_AUTHENTICATION_FAILED';
const _keyEpochUnavailableFailure = 'key-epoch-unavailable';
const _maxPositiveInt63 = 0x7fffffffffffffff;

typedef E2eeSyncSnapshotReader =
    Future<E2eeSyncEntitySnapshot> Function(SyncEntityKey entityKey);

abstract interface class E2eeSyncAuthenticatedRecordTransport {
  String get accountUserId;

  String get actorDeviceId;

  Future<List<CloudSyncRecordMutationResult>> pushRecords(
    List<CloudSyncRecordMutation> mutations,
  );
}

final class E2eeSyncCloudRecordTransport
    implements E2eeSyncAuthenticatedRecordTransport {
  E2eeSyncCloudRecordTransport.bind({
    required this._client,
    required CloudSyncAuthenticatedSession session,
  }) : _token = session.token,
       accountUserId = session.user.id,
       actorDeviceId = session.device.id;

  final CloudSyncClient _client;
  final CloudSyncFullSessionToken _token;

  @override
  final String accountUserId;

  @override
  final String actorDeviceId;

  @override
  Future<List<CloudSyncRecordMutationResult>> pushRecords(
    List<CloudSyncRecordMutation> mutations,
  ) {
    return _client.pushRecordsWithToken(mutations, token: _token);
  }
}

sealed class E2eeSyncEntitySnapshot {
  const E2eeSyncEntitySnapshot();
}

final class E2eeSyncValueSnapshot extends E2eeSyncEntitySnapshot {
  E2eeSyncValueSnapshot._(this.payload);

  factory E2eeSyncValueSnapshot.copyFrom(Uint8List payload) {
    return E2eeSyncValueSnapshot._(Uint8List.fromList(payload));
  }

  // 只持有内部可写副本，调用方即使传入只读视图也不会破坏清零语义。
  final Uint8List payload;
}

final class E2eeSyncTombstoneSnapshot extends E2eeSyncEntitySnapshot {
  const E2eeSyncTombstoneSnapshot();
}

enum E2eeSyncSealStatus { idle, sealed, blocked, raced }

final class E2eeSyncFlushReport {
  const E2eeSyncFlushReport({
    required this.claimed,
    required this.sent,
    required this.applied,
    required this.conflicted,
    required this.rejected,
    required this.quarantined,
    required this.deferred,
    required this.stale,
  });

  const E2eeSyncFlushReport.idle()
    : claimed = 0,
      sent = 0,
      applied = 0,
      conflicted = 0,
      rejected = 0,
      quarantined = 0,
      deferred = 0,
      stale = 0;

  final int claimed;
  final int sent;
  final int applied;
  final int conflicted;
  final int rejected;
  final int quarantined;
  final int deferred;
  final int stale;
}

final class E2eeSyncOutbox implements SyncWriteExecutor {
  E2eeSyncOutbox.takeOwnership({
    required E2eeSyncOutboxCommands commands,
    required this._stateCodec,
    required String accountUserId,
    required String actorDeviceId,
    required int claimedWriterKeyVersion,
  }) : _databaseOwnerKey = commands.ownershipIdentity,
       _commands = commands,
       _accountUserId = _requireCanonicalUuidV4(accountUserId, 'accountUserId'),
       _actorDeviceId = _requireCanonicalUuidV4(actorDeviceId, 'actorDeviceId'),
       _claimedWriterKeyVersion = claimedWriterKeyVersion,
       _processSessionId = const Uuid().v4() {
    if (claimedWriterKeyVersion < 1 || claimedWriterKeyVersion > 0xffffffff) {
      throw ArgumentError.value(
        claimedWriterKeyVersion,
        'claimedWriterKeyVersion',
        '必须位于正 uint32 范围',
      );
    }
    if (_databaseOwners[_databaseOwnerKey] != null) {
      throw StateError('同一数据库已有活动的 E2EE outbox');
    }
    // 安装级文件租约排除其他进程；这里补齐当前 isolate 内的唯一运行时约束。
    _databaseOwners[_databaseOwnerKey] = this;
  }

  static final Expando<E2eeSyncOutbox> _databaseOwners =
      Expando<E2eeSyncOutbox>('e2ee-sync-outbox-owner');

  final Object _databaseOwnerKey;
  final E2eeSyncOutboxCommands _commands;
  final E2eeAccountRecordStateCodec _stateCodec;
  final String _accountUserId;
  final String _actorDeviceId;
  final int _claimedWriterKeyVersion;
  final String _processSessionId;
  final _SerialOperationLock _initializationLock = _SerialOperationLock();
  final _SerialOperationLock _localWriteLock = _SerialOperationLock();
  final _SerialOperationLock _sealLock = _SerialOperationLock();
  final _SerialOperationLock _flushLock = _SerialOperationLock();
  final _SerialOperationLock _cryptoLock = _SerialOperationLock();

  bool _initialized = false;
  bool _closing = false;
  bool _closed = false;
  int _activeOperations = 0;
  Completer<void>? _idleCompleter;
  Future<void>? _closeFuture;

  Future<void> initialize() {
    return _initializationLock.run(() {
      return _runWhileOpen<void>(() async {
        if (_initialized) return;
        _initialized = true;
      }, requireInitialized: false);
    });
  }

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return runLocalBatch(keys: <SyncEntityKey>[key], write: write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    return _runWhileOpen<T>(() {
      return _localWriteLock.run(() async {
        final normalizedKeys = keys.toSet().toList(growable: false);
        if (normalizedKeys.isEmpty) return Future<T>.sync(write);
        for (final key in normalizedKeys) {
          validateSyncEntityKey(key);
        }
        final intents = <E2eeSyncLocalWriteIntent>[
          for (final key in normalizedKeys)
            E2eeSyncLocalWriteIntent(
              intentId: const Uuid().v4(),
              entityKey: key,
            ),
        ];
        return _commands.runLocalWriteAtomically<T>(
          intents: intents,
          writerSessionId: _processSessionId,
          now: _now(),
          write: write,
        );
      });
    });
  }

  Future<E2eeSyncSealStatus> sealNext({
    required E2eeSyncSnapshotReader readSnapshot,
  }) {
    return _runWhileOpen<E2eeSyncSealStatus>(() {
      return _sealLock.run(() async {
        final intents = await _commands.listDirtyIntents(
          limit: _dirtyIntentScanLimit,
        );
        if (intents.isEmpty) return E2eeSyncSealStatus.idle;

        var sawBlocked = false;
        var sawRace = false;
        for (final intent in intents) {
          final lease = await _commands.claimSealIntent(
            intent: intent,
            leaseToken: const Uuid().v4(),
            leaseOwner: _processSessionId,
            leaseExpiresAt: _now().add(_sealLeaseDuration),
            now: _now(),
          );
          if (lease == null) {
            sawRace = true;
            continue;
          }

          var releaseLease = true;
          E2eeSyncEntitySnapshot? snapshot;
          try {
            final recordId = await _cryptoLock.run(
              () => _stateCodec.deriveRecordId(intent.entityKey),
            );
            final plan = await _commands.readSealPlan(
              lease: lease,
              recordId: recordId,
            );
            final currentSnapshot = await readSnapshot(intent.entityKey);
            snapshot = currentSnapshot;
            final operationId = const Uuid().v4();
            final state = await _cryptoLock.run(
              () => switch (currentSnapshot) {
                E2eeSyncValueSnapshot(:final payload) => _stateCodec.sealValue(
                  entityKey: intent.entityKey,
                  logicalVersion: plan.logicalVersion,
                  parentDigests: plan.parentDigests,
                  operationId: operationId,
                  claimedWriterDeviceId: _actorDeviceId,
                  claimedWriterKeyVersion: _claimedWriterKeyVersion,
                  payload: payload,
                ),
                E2eeSyncTombstoneSnapshot() => _stateCodec.sealTombstone(
                  entityKey: intent.entityKey,
                  logicalVersion: plan.logicalVersion,
                  parentDigests: plan.parentDigests,
                  operationId: operationId,
                  claimedWriterDeviceId: _actorDeviceId,
                  claimedWriterKeyVersion: _claimedWriterKeyVersion,
                ),
              },
            );
            final committed = await _commands.commitSealed(
              plan: plan,
              state: state,
              accountUserId: _accountUserId,
              actorDeviceId: _actorDeviceId,
              now: _now(),
            );
            if (!committed) {
              sawRace = true;
              continue;
            }
            releaseLease = false;
            return E2eeSyncSealStatus.sealed;
          } on E2eeSyncOutboxBlocked {
            sawBlocked = true;
          } finally {
            if (snapshot case E2eeSyncValueSnapshot(:final payload)) {
              _clearBytes(payload);
            }
            if (releaseLease) {
              await _commands.releaseSealIntent(lease: lease, now: _now());
            }
          }
        }
        if (sawBlocked) return E2eeSyncSealStatus.blocked;
        if (sawRace) return E2eeSyncSealStatus.raced;
        return E2eeSyncSealStatus.idle;
      });
    });
  }

  Future<E2eeSyncFlushReport> flushOnce({
    required E2eeSyncAuthenticatedRecordTransport transport,
    E2eeSyncExecutionBudget? executionBudget,
  }) {
    return _runWhileOpen<E2eeSyncFlushReport>(() {
      return _flushLock.run(() async {
        if (transport.accountUserId != _accountUserId ||
            transport.actorDeviceId != _actorDeviceId) {
          throw StateError('同步发送端口与 outbox 账号或设备不匹配');
        }
        final now = _now();
        final claims = await _commands.claimSendBatch(
          accountUserId: _accountUserId,
          actorDeviceId: _actorDeviceId,
          leaseOwner: _processSessionId,
          leaseExpiresAt: now.add(_sendLeaseDuration),
          now: now,
        );
        if (claims.isEmpty) return const E2eeSyncFlushReport.idle();

        final prepared = <_PreparedMutation>[];
        final completedPreparationIds = <String>{};
        var quarantined = 0;
        var deferred = 0;
        var stale = 0;
        try {
          for (final claim in claims) {
            try {
              prepared.add(await _prepareMutation(claim));
            } on _E2eeSyncKeyEpochUnavailable {
              final didRelease = await _commands.releaseUnknownResult(
                claim: claim,
                nextAttemptAt: _now().add(_retryDelay(claim.attemptCount)),
                errorKind: _keyEpochUnavailableFailure,
                now: _now(),
              );
              completedPreparationIds.add(claim.operationId);
              if (didRelease) {
                deferred += 1;
              } else {
                stale += 1;
              }
            } catch (error) {
              if (!_isPersistedCiphertextCorruption(error)) rethrow;
              final didQuarantine = await _commands.quarantineCorrupt(
                claim: claim,
                errorCode: _localCiphertextAuthenticationFailure,
                now: _now(),
              );
              completedPreparationIds.add(claim.operationId);
              if (didQuarantine) {
                quarantined += 1;
              } else {
                stale += 1;
              }
            }
          }
        } catch (error, stackTrace) {
          await _releaseUnknownClaims(
            claims.where(
              (claim) => !completedPreparationIds.contains(claim.operationId),
            ),
            errorKind: _failureKind(error),
          );
          Error.throwWithStackTrace(error, stackTrace);
        }

        if (prepared.isEmpty) {
          return E2eeSyncFlushReport(
            claimed: claims.length,
            sent: 0,
            applied: 0,
            conflicted: 0,
            rejected: 0,
            quarantined: quarantined,
            deferred: deferred,
            stale: stale,
          );
        }

        late List<CloudSyncRecordMutationResult> results;
        try {
          final mutations = prepared
              .map((item) => item.mutation)
              .toList(growable: false);
          results = executionBudget == null
              ? await transport.pushRecords(mutations)
              : await executionBudget.runNetworkStep(
                  operation: (_) => transport.pushRecords(mutations),
                );
          _requireCompleteResults(results, prepared);
        } catch (error, stackTrace) {
          await _releaseUnknownClaims(
            prepared.map((item) => item.claim),
            errorKind: _failureKind(error),
          );
          Error.throwWithStackTrace(error, stackTrace);
        }

        final resultsById = <String, CloudSyncRecordMutationResult>{
          for (final result in results) result.mutationId: result,
        };
        var applied = 0;
        var conflicted = 0;
        var rejected = 0;
        for (final item in prepared) {
          final result = resultsById[item.claim.operationId]!;
          final settled = switch (result) {
            CloudSyncAppliedMutationResult() => _settleApplied(item, result),
            CloudSyncConflictMutationResult() => _commands.settleConflict(
              claim: item.claim,
              currentRevision: result.currentRevision,
              newIntentId: const Uuid().v4(),
              now: _now(),
            ),
            CloudSyncRejectedMutationResult() => _commands.settleRejected(
              claim: item.claim,
              errorCode: result.errorCode,
              now: _now(),
            ),
          };
          if (!await settled) {
            stale += 1;
            continue;
          }
          switch (result) {
            case CloudSyncAppliedMutationResult():
              applied += 1;
              break;
            case CloudSyncConflictMutationResult():
              conflicted += 1;
              break;
            case CloudSyncRejectedMutationResult():
              rejected += 1;
              break;
          }
        }
        return E2eeSyncFlushReport(
          claimed: claims.length,
          sent: prepared.length,
          applied: applied,
          conflicted: conflicted,
          rejected: rejected,
          quarantined: quarantined,
          deferred: deferred,
          stale: stale,
        );
      });
    });
  }

  Future<void> close() {
    return _closeFuture ??= _closeAndResetOnFailure();
  }

  Future<_PreparedMutation> _prepareMutation(
    E2eeSyncClaimedOutboxMutation claim,
  ) async {
    if (claim.accountUserId != _accountUserId ||
        claim.actorDeviceId != _actorDeviceId) {
      throw StateError('outbox 账号或发送设备不匹配');
    }
    if (claim.keyEpoch > _stateCodec.currentKeyEpoch) {
      throw const _E2eeSyncKeyEpochUnavailable();
    }
    final envelope = E2eeUntrustedAccountRecordEnvelope.fromTransport(
      recordId: E2eeUntrustedAccountRecordId.fromTransport(claim.recordId),
      envelopeVersion: claim.envelopeVersion,
      keyEpoch: claim.keyEpoch,
      ciphertext: claim.ciphertext,
    );
    final restored = await _cryptoLock.run(
      () => _stateCodec.restoreForSend(envelope, expectedDigest: claim.digest),
    );
    final state = restored.sealed;
    final authenticated = restored.authenticated;
    if (state.record.recordId.wireValue != claim.recordId ||
        state.record.keyEpoch != claim.keyEpoch ||
        state.digest != claim.digest ||
        state.operationId != claim.operationId ||
        state.claimedWriterDeviceId != claim.actorDeviceId ||
        state.claimedWriterKeyVersion != claim.claimedWriterKeyVersion ||
        state.record.ciphertext.length != claim.ciphertext.length ||
        !_sameBytes(state.record.ciphertext, claim.ciphertext)) {
      throw const FormatException('outbox 密文与持久化元数据不匹配');
    }
    if (authenticated.recordId.wireValue != claim.recordId ||
        authenticated.entityKey != claim.entityKey ||
        authenticated.digest != claim.digest ||
        authenticated.operationId != claim.operationId ||
        authenticated.claimedWriterDeviceId != claim.actorDeviceId ||
        authenticated.claimedWriterKeyVersion !=
            claim.claimedWriterKeyVersion ||
        authenticated.keyEpoch != claim.keyEpoch) {
      throw const FormatException('outbox 实体键与认证密文不匹配');
    }
    return _PreparedMutation(
      claim: claim,
      authenticated: authenticated,
      mutation: CloudSyncPutRecordMutation(
        mutationId: claim.operationId,
        expectedRevision: claim.expectedRevision,
        state: state,
      ),
    );
  }

  Future<bool> _settleApplied(
    _PreparedMutation item,
    CloudSyncAppliedMutationResult result,
  ) async {
    final authenticated = item.authenticated;
    if (authenticated.recordId.wireValue != item.claim.recordId ||
        authenticated.entityKey != item.claim.entityKey ||
        authenticated.digest != item.claim.digest ||
        authenticated.operationId != item.claim.operationId ||
        authenticated.claimedWriterDeviceId != item.claim.actorDeviceId ||
        authenticated.claimedWriterKeyVersion !=
            item.claim.claimedWriterKeyVersion ||
        authenticated.keyEpoch != item.claim.keyEpoch) {
      throw const FormatException('applied 结果对应的认证状态不匹配');
    }
    return _commands.settleApplied(
      claim: item.claim,
      state: authenticated,
      revision: result.revision,
      changeSeq: result.changeSeq,
      now: _now(),
    );
  }

  Future<void> _releaseUnknownClaims(
    Iterable<E2eeSyncClaimedOutboxMutation> claims, {
    required String errorKind,
  }) async {
    for (final claim in claims) {
      await _commands.releaseUnknownResult(
        claim: claim,
        nextAttemptAt: _now().add(_retryDelay(claim.attemptCount)),
        errorKind: errorKind,
        now: _now(),
      );
    }
  }

  Future<T> _runWhileOpen<T>(
    Future<T> Function() action, {
    bool requireInitialized = true,
  }) async {
    if (_closing || _closed) throw StateError('E2EE outbox 已关闭');
    if (requireInitialized && !_initialized) {
      throw StateError('E2EE outbox 尚未初始化');
    }
    _activeOperations += 1;
    try {
      return await action();
    } finally {
      _activeOperations -= 1;
      if (_activeOperations == 0) {
        _idleCompleter?.complete();
        _idleCompleter = null;
      }
    }
  }

  Future<void> _closeAndResetOnFailure() async {
    try {
      if (_closed) return;
      _closing = true;
      if (_activeOperations > 0) {
        _idleCompleter ??= Completer<void>();
        await _idleCompleter!.future;
      }
      await _stateCodec.close();
      _closed = true;
      if (identical(_databaseOwners[_databaseOwnerKey], this)) {
        _databaseOwners[_databaseOwnerKey] = null;
      }
    } catch (_) {
      _closing = false;
      _closeFuture = null;
      rethrow;
    }
  }
}

final class _PreparedMutation {
  const _PreparedMutation({
    required this.claim,
    required this.authenticated,
    required this.mutation,
  });

  final E2eeSyncClaimedOutboxMutation claim;
  final E2eeAuthenticatedAccountRecordState authenticated;
  final CloudSyncPutRecordMutation mutation;
}

final class _E2eeSyncKeyEpochUnavailable implements Exception {
  const _E2eeSyncKeyEpochUnavailable();
}

final class _SerialOperationLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) async {
    final previous = _tail;
    final completed = Completer<void>();
    _tail = completed.future;
    await previous;
    try {
      return await action();
    } finally {
      completed.complete();
    }
  }
}

void _requireCompleteResults(
  List<CloudSyncRecordMutationResult> results,
  List<_PreparedMutation> prepared,
) {
  if (results.length != prepared.length) {
    throw const FormatException('服务端返回的 outbox 结果数量不匹配');
  }
  final expectedIds = <String>{
    for (final item in prepared) item.claim.operationId,
  };
  final returnedIds = <String>{};
  for (final result in results) {
    if (!expectedIds.contains(result.mutationId) ||
        !returnedIds.add(result.mutationId)) {
      throw const FormatException('服务端返回了未知或重复的 outbox 结果');
    }
    final expectedRevision = prepared
        .singleWhere((item) => item.claim.operationId == result.mutationId)
        .claim
        .expectedRevision;
    switch (result) {
      case CloudSyncAppliedMutationResult(:final revision, :final changeSeq):
        if (revision != expectedRevision + 1 ||
            revision > _maxPositiveInt63 ||
            changeSeq < 0 ||
            changeSeq > _maxPositiveInt63) {
          throw const FormatException('服务端返回了无效的 applied outbox 结果');
        }
        break;
      case CloudSyncConflictMutationResult(:final currentRevision):
        if (currentRevision != null &&
            (currentRevision < 1 || currentRevision > _maxPositiveInt63)) {
          throw const FormatException('服务端返回了无效的 conflict outbox 结果');
        }
        break;
      case CloudSyncRejectedMutationResult(:final errorCode):
        final errorCodeBytes = utf8.encode(errorCode).length;
        if (errorCodeBytes < 1 || errorCodeBytes > 100) {
          throw const FormatException('服务端返回了无效的 rejected outbox 结果');
        }
        break;
    }
  }
}

bool _isPersistedCiphertextCorruption(Object error) {
  if (error is FormatException) return true;
  return error is KelivoSecureCoreException &&
      (error.status == KelivoSecureCoreStatus.recordEnvelopeInvalid ||
          error.status == KelivoSecureCoreStatus.recordAuthenticationFailed);
}

String _failureKind(Object error) => switch (error) {
  CloudSyncException(:final kind) => kind.name,
  TimeoutException() => CloudSyncFailureKind.timeout.name,
  _ => CloudSyncFailureKind.unknown.name,
};

Duration _retryDelay(int attemptCount) {
  final boundedAttempt = attemptCount < 1
      ? 1
      : (attemptCount > 8 ? 8 : attemptCount);
  return Duration(seconds: 1 << boundedAttempt);
}

DateTime _now() => DateTime.now().toUtc();

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

void _clearBytes(Uint8List value) {
  if (value.isNotEmpty) value.fillRange(0, value.length, 0);
}

String _requireCanonicalUuidV4(String value, String field) {
  final bytes = Uint8List.fromList(Uuid.parseAsByteList(value));
  if (bytes.length != 16 ||
      (bytes[6] & 0xf0) != 0x40 ||
      (bytes[8] & 0xc0) != 0x80 ||
      Uuid.unparse(bytes) != value) {
    throw FormatException('$field 必须为规范小写 UUID v4');
  }
  return value;
}
