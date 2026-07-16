import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class SyncEntityKey {
  const SyncEntityKey({required this.entityType, required this.entityId});

  final String entityType;
  final String entityId;

  String get storageKey => '$entityType\u0000$entityId';

  @override
  bool operator ==(Object other) {
    return other is SyncEntityKey &&
        other.entityType == entityType &&
        other.entityId == entityId;
  }

  @override
  int get hashCode => Object.hash(entityType, entityId);
}

@immutable
class LocalSyncEntity {
  LocalSyncEntity({
    required this.entityType,
    required this.entityId,
    required Map<String, Object?> payload,
    this.parentId,
    this.schemaVersion = 2,
  }) : payload = validateSyncJsonObject(payload);

  final String entityType;
  final String entityId;
  final String? parentId;
  final int schemaVersion;
  final Map<String, Object?> payload;

  SyncEntityKey get key =>
      SyncEntityKey(entityType: entityType, entityId: entityId);
}

@immutable
class RemoteSyncEntity {
  RemoteSyncEntity({
    required this.entityType,
    required this.entityId,
    required this.revision,
    required this.schemaVersion,
    required Map<String, Object?> payload,
    required this.updatedAt,
    this.parentId,
  }) : payload = validateSyncJsonObject(payload);

  final String entityType;
  final String entityId;
  final String? parentId;
  final int revision;
  final int schemaVersion;
  final Map<String, Object?> payload;
  final DateTime updatedAt;

  SyncEntityKey get key =>
      SyncEntityKey(entityType: entityType, entityId: entityId);
}

abstract interface class SyncEntityAdapter {
  Set<String> get entityTypes;

  int get applyPriority;

  Future<List<LocalSyncEntity>> exportLocalEntities();

  Future<void> applyRemoteUpsert(RemoteSyncEntity entity);

  Future<void> applyRemoteDelete(SyncEntityKey key);
}

Map<String, Object?> validateSyncJsonObject(Map<String, Object?> value) {
  final normalized = _normalizeJsonValue(value);
  if (normalized is! Map<String, Object?>) {
    throw const FormatException('同步数据必须是 JSON 对象');
  }
  return normalized;
}

String canonicalSyncJson(Map<String, Object?> value) {
  return jsonEncode(_canonicalizeJson(validateSyncJsonObject(value)));
}

Object? _normalizeJsonValue(Object? value) {
  if (value == null || value is String || value is bool) {
    return value;
  }
  if (value is num) {
    if (!value.isFinite) {
      throw const FormatException('同步数据不能包含非有限数字');
    }
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_normalizeJsonValue));
  }
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, item) => MapEntry(key, _normalizeJsonValue(item))),
    );
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('同步对象键必须是字符串');
      }
      result[entry.key as String] = _normalizeJsonValue(entry.value);
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  throw FormatException('同步数据包含不支持的类型：${value.runtimeType}');
}

Object? _canonicalizeJson(Object? value) {
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalizeJson(value[key]),
    };
  }
  if (value is List<Object?>) {
    return value.map(_canonicalizeJson).toList(growable: false);
  }
  return value;
}
