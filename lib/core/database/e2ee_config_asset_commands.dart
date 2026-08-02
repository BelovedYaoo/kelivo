part of 'chat_database_repository.dart';

final class E2eeConfigAssetRecord {
  const E2eeConfigAssetRecord._({
    required this.key,
    required this.asset,
    required this.remoteIdentity,
  });

  final E2eeConfigAssetKey key;
  final MessageAssetRegistration asset;
  final E2eeConfigAssetRemoteIdentity? remoteIdentity;
}

final class E2eeConfigAssetCommands {
  E2eeConfigAssetCommands._(this._database);

  final AppDatabase _database;

  Future<E2eeConfigAssetRecord?> read(E2eeConfigAssetKey key) async {
    final reference = await _readReference(key);
    if (reference == null) return null;
    final asset = await (_database.select(
      _database.assetRows,
    )..where((row) => row.id.equals(reference.assetId))).getSingleOrNull();
    if (asset == null) throw StateError('配置资产引用缺少本地资产');
    return _configAssetRecordFromRows(key, reference, asset);
  }

  Future<bool> replace({
    required E2eeConfigAssetKey key,
    required MessageAssetRegistration asset,
    required DateTime now,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    final identity = _configAssetIdentityFromRegistration(asset);
    _requireConfigAssetRegistration(key, asset, identity);
    return _database.transaction(() async {
      final previous = await _readReference(key);
      await (_database.delete(_database.e2eeAttachmentUploadRows)..where(
            (row) =>
                row.targetConfigEntityType.equals(key.entityKey.entityType) &
                row.targetConfigEntityId.equals(key.entityKey.entityId) &
                row.targetConfigSlot.equals(key.slot.wireValue),
          ))
          .go();
      await _registerConfigAsset(asset, timestamp);
      await _database
          .into(_database.configAssetRows)
          .insertOnConflictUpdate(
            ConfigAssetRowsCompanion.insert(
              entityType: key.entityKey.entityType,
              entityId: key.entityKey.entityId,
              slot: key.slot.wireValue,
              assetId: asset.assetId,
              kind: asset.kind,
              displayName: Value(asset.displayName),
              mediaType: Value(asset.mediaType),
              attachmentId: Value(identity?.attachmentId),
              uploadId: Value(identity?.uploadId),
              chunkKeyEpoch: Value(identity?.chunkKeyEpoch),
              manifestKeyEpoch: Value(identity?.manifestKeyEpoch),
              manifestRevision: Value(identity?.manifestRevision),
            ),
          );
      await (_database.delete(
        _database.assetGcRows,
      )..where((row) => row.assetId.equals(asset.assetId))).go();
      return previous != null && previous.assetId != asset.assetId;
    });
  }

  Future<bool> remove(E2eeConfigAssetKey key) {
    return _database.transaction(() async {
      final previous = await _readReference(key);
      if (previous == null) return false;
      final deleted =
          await (_database.delete(_database.configAssetRows)..where(
                (row) =>
                    row.entityType.equals(key.entityKey.entityType) &
                    row.entityId.equals(key.entityKey.entityId) &
                    row.slot.equals(key.slot.wireValue),
              ))
              .go();
      if (deleted != 1) throw StateError('配置资产删除数量异常');
      return true;
    });
  }

  Future<ConfigAssetRow?> _readReference(E2eeConfigAssetKey key) {
    return (_database.select(_database.configAssetRows)..where(
          (row) =>
              row.entityType.equals(key.entityKey.entityType) &
              row.entityId.equals(key.entityKey.entityId) &
              row.slot.equals(key.slot.wireValue),
        ))
        .getSingleOrNull();
  }

  Future<void> _registerConfigAsset(
    MessageAssetRegistration asset,
    DateTime timestamp,
  ) async {
    await _database
        .into(_database.assetRows)
        .insert(
          AssetRowsCompanion.insert(
            id: asset.assetId,
            contentHash: asset.contentHash,
            path: asset.path,
            byteSize: asset.byteSize,
            width: Value(asset.width),
            height: Value(asset.height),
            thumbnailPath: Value(asset.thumbnailPath),
            createdAt: timestamp,
            lastReferencedAt: timestamp,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final persisted = await (_database.select(
      _database.assetRows,
    )..where((row) => row.id.equals(asset.assetId))).getSingleOrNull();
    if (persisted == null ||
        persisted.contentHash != asset.contentHash ||
        persisted.path != asset.path ||
        persisted.byteSize != asset.byteSize ||
        persisted.width != asset.width ||
        persisted.height != asset.height ||
        persisted.thumbnailPath != asset.thumbnailPath) {
      throw StateError('配置资产注册与既有本地资产不一致');
    }
    if (persisted.lastReferencedAt.isBefore(timestamp)) {
      await (_database.update(_database.assetRows)
            ..where((row) => row.id.equals(asset.assetId)))
          .write(AssetRowsCompanion(lastReferencedAt: Value(timestamp)));
    }
  }
}

E2eeConfigAssetRecord _configAssetRecordFromRows(
  E2eeConfigAssetKey key,
  ConfigAssetRow reference,
  AssetRow asset,
) {
  final identity = _configAssetIdentityFromColumns(
    attachmentId: reference.attachmentId,
    uploadId: reference.uploadId,
    chunkKeyEpoch: reference.chunkKeyEpoch,
    manifestKeyEpoch: reference.manifestKeyEpoch,
    manifestRevision: reference.manifestRevision,
    kind: reference.kind,
  );
  return E2eeConfigAssetRecord._(
    key: key,
    asset: MessageAssetRegistration(
      assetId: asset.id,
      contentHash: asset.contentHash,
      path: asset.path,
      byteSize: asset.byteSize,
      kind: reference.kind,
      displayName: reference.displayName,
      mediaType: reference.mediaType,
      attachmentId: identity?.attachmentId,
      uploadId: identity?.uploadId,
      chunkKeyEpoch: identity?.chunkKeyEpoch,
      manifestKeyEpoch: identity?.manifestKeyEpoch,
      manifestRevision: identity?.manifestRevision,
      width: asset.width,
      height: asset.height,
      thumbnailPath: asset.thumbnailPath,
    ),
    remoteIdentity: identity,
  );
}

E2eeConfigAssetRemoteIdentity? _configAssetIdentityFromRegistration(
  MessageAssetRegistration asset,
) => _configAssetIdentityFromColumns(
  attachmentId: asset.attachmentId,
  uploadId: asset.uploadId,
  chunkKeyEpoch: asset.chunkKeyEpoch,
  manifestKeyEpoch: asset.manifestKeyEpoch,
  manifestRevision: asset.manifestRevision,
  kind: asset.kind,
);

E2eeConfigAssetRemoteIdentity? _configAssetIdentityFromColumns({
  required String? attachmentId,
  required String? uploadId,
  required int? chunkKeyEpoch,
  required int? manifestKeyEpoch,
  required int? manifestRevision,
  required String kind,
}) {
  final values = <Object?>[
    attachmentId,
    uploadId,
    chunkKeyEpoch,
    manifestKeyEpoch,
    manifestRevision,
  ];
  if (values.every((value) => value == null)) return null;
  if (values.any((value) => value == null)) {
    throw const FormatException('配置资产远端身份必须完整');
  }
  return E2eeConfigAssetRemoteIdentity(
    attachmentId: attachmentId!,
    uploadId: uploadId!,
    chunkKeyEpoch: chunkKeyEpoch!,
    manifestKeyEpoch: manifestKeyEpoch!,
    manifestRevision: manifestRevision!,
    kind: _configAssetKind(kind),
  );
}

void _requireConfigAssetRegistration(
  E2eeConfigAssetKey key,
  MessageAssetRegistration asset,
  E2eeConfigAssetRemoteIdentity? identity,
) {
  final assetId = _requireAttachmentStorageText(asset.assetId, 'assetId', 1024);
  final contentHash = asset.contentHash;
  final path = _requireAttachmentStorageText(asset.path, 'path', 32768);
  if (assetId != asset.assetId ||
      path != asset.path ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(contentHash) ||
      asset.byteSize < 0 ||
      asset.kind != _configAssetKindForSlot(key.slot).name ||
      asset.thumbnailPath != null ||
      (identity != null && identity.kind.name != asset.kind)) {
    throw const FormatException('配置资产注册字段无效');
  }
  if (asset.kind == E2eeAttachmentKind.file.name) {
    if (asset.displayName == null || asset.mediaType == null) {
      throw const FormatException('配置文件资产缺少显示名称或媒体类型');
    }
  } else if (asset.displayName != null || asset.mediaType != null) {
    throw const FormatException('配置图片资产不得携带文件元数据');
  }
}

E2eeAttachmentKind _configAssetKindForSlot(E2eeConfigAssetSlot slot) =>
    switch (slot) {
      E2eeConfigAssetSlot.avatar ||
      E2eeConfigAssetSlot.background => E2eeAttachmentKind.image,
      E2eeConfigAssetSlot.appFont ||
      E2eeConfigAssetSlot.codeFont => E2eeAttachmentKind.file,
    };

E2eeAttachmentKind _configAssetKind(String value) {
  return switch (value) {
    'image' => E2eeAttachmentKind.image,
    'file' => E2eeAttachmentKind.file,
    _ => throw const FormatException('配置资产 kind 无效'),
  };
}
