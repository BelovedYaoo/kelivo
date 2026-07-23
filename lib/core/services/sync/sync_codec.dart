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
