import 'cloud_sync_client.dart';
import 'cloud_sync_store.dart';
import 'cloud_sync_types.dart';
import 'sync_codec.dart';
import 'sync_write_journal.dart';

enum CloudSyncConflictResolutionFailureReason {
  conflictNotOpen,
  invalidLocalPath,
  unsupportedNestedPath,
  duplicateConflictPath,
  duplicateAdapterEntityType,
  unsupportedEntityType,
  incompleteConflictList,
  conflictIdentityChanged,
  conflictDetailsChanged,
  entityHasAnotherConflict,
  invalidShadow,
  entityHasOutbox,
  verificationMismatch,
  invalidResolveResult,
}

final class CloudSyncConflictResolutionException implements Exception {
  const CloudSyncConflictResolutionException(this.reason);

  final CloudSyncConflictResolutionFailureReason reason;

  @override
  String toString() {
    return 'CloudSyncConflictResolutionException(${reason.name})';
  }
}

typedef CloudSyncSynchronize = Future<void> Function();

final class CloudSyncConflictResolver {
  factory CloudSyncConflictResolver({
    required CloudSyncAccountSession session,
    required CloudSyncConflictTransport client,
    required CloudSyncStore store,
    required SyncWriteJournal writeJournal,
    required Iterable<SyncEntityAdapter> adapters,
    required CloudSyncSynchronize synchronize,
  }) {
    return CloudSyncConflictResolver._(
      session: session,
      client: client,
      store: store,
      writeJournal: writeJournal,
      adapterByType: _indexAdapters(adapters),
      synchronize: synchronize,
    );
  }

  CloudSyncConflictResolver._({
    required this._session,
    required this._client,
    required this._store,
    required this._writeJournal,
    required this._adapterByType,
    required this._synchronize,
  });

  static const int _conflictPageLimit = 100;

  final CloudSyncAccountSession _session;
  final CloudSyncConflictTransport _client;
  final CloudSyncStore _store;
  final SyncWriteJournal _writeJournal;
  final Map<String, SyncEntityAdapter> _adapterByType;
  final CloudSyncSynchronize _synchronize;

  Future<CloudSyncConflict> resolve(
    CloudSyncConflict conflict,
    Set<String> localPaths,
  ) async {
    final selectedPaths = Set<String>.unmodifiable(localPaths);
    if (conflict.state != CloudSyncConflictState.open) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.conflictNotOpen,
      );
    }
    if (selectedPaths.isEmpty) {
      return _resolveOnServer(conflict);
    }
    final selectedFields = _selectedFields(conflict, selectedPaths);
    final adapter = _adapterByType[conflict.entityType.wireName];
    if (adapter == null) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.unsupportedEntityType,
      );
    }
    final key = SyncEntityKey(
      entityType: conflict.entityType.wireName,
      entityId: conflict.entityId,
    );

    await _synchronize();
    _requireStableOpenConflict(
      conflict,
      await _listCompleteOpenConflicts(),
      selectedFields,
    );
    final shadow = _requireCleanShadow(conflict);
    final payload = _applyDesiredFields(shadow.payload!, selectedFields);

    // 通过本地写前 journal 记录这次人工选择，使同步协调器仍是唯一的上传路径。
    await _writeJournal.runLocal<void>(
      key: key,
      write: () => adapter.applyRemoteUpsert(
        RemoteSyncEntity(
          entityType: key.entityType,
          entityId: key.entityId,
          parentId: shadow.parentId,
          revision: shadow.revision,
          schemaVersion: shadow.schemaVersion,
          payload: payload,
          updatedAt: shadow.updatedAt,
        ),
      ),
    );

    await _synchronize();
    _requireStableOpenConflict(
      conflict,
      await _listCompleteOpenConflicts(),
      selectedFields,
    );
    final verifiedShadow = _requireCleanShadow(conflict);
    if (!_matchesDesiredFields(verifiedShadow.payload!, selectedFields)) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.verificationMismatch,
      );
    }

    return _resolveOnServer(conflict);
  }

  Map<String, CloudSyncConflictField> _selectedFields(
    CloudSyncConflict conflict,
    Set<String> selectedPaths,
  ) {
    final fieldsByPath = <String, CloudSyncConflictField>{};
    for (final field in conflict.fields) {
      if (fieldsByPath.containsKey(field.path)) {
        throw const CloudSyncConflictResolutionException(
          CloudSyncConflictResolutionFailureReason.duplicateConflictPath,
        );
      }
      fieldsByPath[field.path] = field;
    }

    final selected = <String, CloudSyncConflictField>{};
    for (final path in selectedPaths) {
      final field = fieldsByPath[path];
      if (field == null) {
        throw const CloudSyncConflictResolutionException(
          CloudSyncConflictResolutionFailureReason.invalidLocalPath,
        );
      }
      if (!_isTopLevelPointer(path)) {
        throw const CloudSyncConflictResolutionException(
          CloudSyncConflictResolutionFailureReason.unsupportedNestedPath,
        );
      }
      selected[path] = field;
    }
    return Map<String, CloudSyncConflictField>.unmodifiable(selected);
  }

  Future<List<CloudSyncConflict>> _listCompleteOpenConflicts() async {
    final conflicts = await _client.listConflicts(
      state: CloudSyncConflictState.open,
      limit: _conflictPageLimit,
    );
    if (conflicts.length >= _conflictPageLimit) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.incompleteConflictList,
      );
    }
    return conflicts;
  }

  void _requireStableOpenConflict(
    CloudSyncConflict expected,
    List<CloudSyncConflict> openConflicts,
    Map<String, CloudSyncConflictField> selectedFields,
  ) {
    CloudSyncConflict? current;
    for (final conflict in openConflicts) {
      if (conflict.conflictId == expected.conflictId) {
        current = conflict;
        break;
      }
    }
    if (current == null || current.state != CloudSyncConflictState.open) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.conflictNotOpen,
      );
    }
    if (!_isSameEntity(current, expected)) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.conflictIdentityChanged,
      );
    }
    if (current.mutationId != expected.mutationId ||
        current.baseRevision != expected.baseRevision ||
        !_selectedDesiredFieldsMatch(current, selectedFields)) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.conflictDetailsChanged,
      );
    }
    if (openConflicts.any(
      (conflict) =>
          conflict.conflictId != expected.conflictId &&
          _isSameEntity(conflict, expected),
    )) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.entityHasAnotherConflict,
      );
    }
  }

  bool _selectedDesiredFieldsMatch(
    CloudSyncConflict current,
    Map<String, CloudSyncConflictField> selectedFields,
  ) {
    final currentFields = <String, CloudSyncConflictField>{};
    for (final field in current.fields) {
      if (currentFields.containsKey(field.path)) return false;
      currentFields[field.path] = field;
    }
    for (final entry in selectedFields.entries) {
      final currentField = currentFields[entry.key];
      if (currentField == null ||
          !_fieldStatesMatch(currentField.desired, entry.value.desired)) {
        return false;
      }
    }
    return true;
  }

  CloudSyncShadow _requireCleanShadow(CloudSyncConflict conflict) {
    if (_store
        .outboxForEntity(
          _session,
          entityType: conflict.entityType,
          entityId: conflict.entityId,
        )
        .isNotEmpty) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.entityHasOutbox,
      );
    }
    final shadow = _store.shadow(
      _session,
      entityType: conflict.entityType,
      entityId: conflict.entityId,
    );
    if (shadow == null || shadow.deleted || shadow.payload == null) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.invalidShadow,
      );
    }
    try {
      canonicalSyncJson(shadow.payload!);
    } on FormatException {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.invalidShadow,
      );
    }
    return shadow;
  }

  Map<String, Object?> _applyDesiredFields(
    Map<String, Object?> shadowPayload,
    Map<String, CloudSyncConflictField> selectedFields,
  ) {
    final result = <String, Object?>{...shadowPayload};
    for (final entry in selectedFields.entries) {
      final fieldName = _decodeTopLevelPointer(entry.key);
      final desired = entry.value.desired;
      if (desired.exists) {
        result[fieldName] = copyCloudSyncJsonValue(desired.value);
      } else {
        result.remove(fieldName);
      }
    }
    return validateSyncJsonObject(result);
  }

  bool _matchesDesiredFields(
    Map<String, Object?> shadowPayload,
    Map<String, CloudSyncConflictField> selectedFields,
  ) {
    for (final entry in selectedFields.entries) {
      final fieldName = _decodeTopLevelPointer(entry.key);
      final desired = entry.value.desired;
      final exists = shadowPayload.containsKey(fieldName);
      if (exists != desired.exists) return false;
      if (exists &&
          canonicalSyncJson(<String, Object?>{
                'value': shadowPayload[fieldName],
              }) !=
              canonicalSyncJson(<String, Object?>{'value': desired.value})) {
        return false;
      }
    }
    return true;
  }

  Future<CloudSyncConflict> _resolveOnServer(CloudSyncConflict expected) async {
    final resolved = await _client.resolveConflict(expected.conflictId);
    if (resolved.conflictId != expected.conflictId ||
        resolved.state != CloudSyncConflictState.resolved) {
      throw const CloudSyncConflictResolutionException(
        CloudSyncConflictResolutionFailureReason.invalidResolveResult,
      );
    }
    return resolved;
  }

  static Map<String, SyncEntityAdapter> _indexAdapters(
    Iterable<SyncEntityAdapter> adapters,
  ) {
    final result = <String, SyncEntityAdapter>{};
    for (final adapter in adapters) {
      for (final entityType in adapter.entityTypes) {
        try {
          CloudSyncEntityType.parse(entityType);
        } on FormatException {
          throw const CloudSyncConflictResolutionException(
            CloudSyncConflictResolutionFailureReason.unsupportedEntityType,
          );
        }
        if (result.containsKey(entityType)) {
          throw const CloudSyncConflictResolutionException(
            CloudSyncConflictResolutionFailureReason.duplicateAdapterEntityType,
          );
        }
        result[entityType] = adapter;
      }
    }
    return Map<String, SyncEntityAdapter>.unmodifiable(result);
  }

  static bool _isSameEntity(CloudSyncConflict left, CloudSyncConflict right) {
    return left.entityType == right.entityType &&
        left.entityId == right.entityId;
  }

  static bool _isTopLevelPointer(String path) {
    if (path.length <= 1 || !path.startsWith('/')) return false;
    for (var index = 1; index < path.length; index++) {
      final character = path[index];
      if (character == '/') return false;
      if (character != '~') continue;
      if (index + 1 >= path.length) return false;
      final escaped = path[++index];
      if (escaped != '0' && escaped != '1') return false;
    }
    return true;
  }

  static String _decodeTopLevelPointer(String path) {
    final result = StringBuffer();
    for (var index = 1; index < path.length; index++) {
      final character = path[index];
      if (character != '~') {
        result.write(character);
        continue;
      }
      final escaped = path[++index];
      result.write(escaped == '0' ? '~' : '/');
    }
    return result.toString();
  }

  static bool _fieldStatesMatch(
    CloudSyncConflictFieldState left,
    CloudSyncConflictFieldState right,
  ) {
    if (left.exists != right.exists) return false;
    if (!left.exists) return true;
    return canonicalSyncJson(<String, Object?>{'value': left.value}) ==
        canonicalSyncJson(<String, Object?>{'value': right.value});
  }
}
