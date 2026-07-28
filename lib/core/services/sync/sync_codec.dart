import 'dart:convert';

import 'package:flutter/foundation.dart';

const syncEntityTypeMaxBytes = 64;
const syncEntityIdMaxBytes = 1024;

final _syncEntityTypePattern = RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$');

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

void validateSyncEntityKey(SyncEntityKey key) {
  if (!_syncEntityTypePattern.hasMatch(key.entityType)) {
    throw const FormatException('同步实体类型必须为小写 kebab-case');
  }
  if (key.entityId.isEmpty || key.entityId.contains('\u0000')) {
    throw const FormatException('同步实体 ID 不能为空或包含 NUL');
  }
  if (!_isWellFormedUtf16(key.entityId)) {
    throw const FormatException('entityId 包含未配对的 UTF-16 代理项');
  }
  if (utf8.encode(key.entityType).length > syncEntityTypeMaxBytes) {
    throw const FormatException('同步实体类型长度无效');
  }
  if (utf8.encode(key.entityId).length > syncEntityIdMaxBytes) {
    throw const FormatException('同步实体 ID 长度无效');
  }
}

bool _isWellFormedUtf16(String value) {
  for (var index = 0; index < value.length; index++) {
    final codeUnit = value.codeUnitAt(index);
    if (codeUnit >= 0xd800 && codeUnit <= 0xdbff) {
      if (++index >= value.length) return false;
      final trailing = value.codeUnitAt(index);
      if (trailing < 0xdc00 || trailing > 0xdfff) return false;
    } else if (codeUnit >= 0xdc00 && codeUnit <= 0xdfff) {
      return false;
    }
  }
  return true;
}
