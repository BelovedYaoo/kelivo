import '../../models/chat_message.dart';
import 'e2ee_config_asset_types.dart';
import 'sync_codec.dart';

abstract interface class SyncWriteExecutor {
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  });

  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  });
}

final class StructuredMessageAttachmentSyncTarget {
  StructuredMessageAttachmentSyncTarget({
    required this.targetRevisionId,
    required Iterable<ChatMessageAttachment> attachments,
  }) : attachments = List<ChatMessageAttachment>.unmodifiable(attachments);

  final String targetRevisionId;
  final List<ChatMessageAttachment> attachments;
}

/// 为账户工作区提供结构化附件的内容落盘与事务上传草稿能力。
abstract interface class StructuredAttachmentSyncWriteExecutor
    implements SyncWriteExecutor {
  Future<List<ChatMessageAttachment>> materializeLocalAttachments(
    Iterable<ChatMessageAttachment> attachments,
  );

  Future<T> runLocalBatchWithMessageAttachments<T>({
    required Iterable<SyncEntityKey> keys,
    required Iterable<StructuredMessageAttachmentSyncTarget> targets,
    required bool Function(T result) targetWasPersisted,
    required Future<T> Function() write,
  });
}

final class LocalConfigAssetInput {
  const LocalConfigAssetInput({
    required this.key,
    required this.sourcePath,
    required this.kind,
    this.displayName,
    this.mediaType,
  });

  final E2eeConfigAssetKey key;
  final String sourcePath;
  final String kind;
  final String? displayName;
  final String? mediaType;
}

final class MaterializedConfigAsset {
  const MaterializedConfigAsset({
    required this.key,
    required this.assetId,
    required this.path,
    required this.contentHash,
    required this.byteSize,
    required this.kind,
    this.displayName,
    this.mediaType,
  });

  final E2eeConfigAssetKey key;
  final String assetId;
  final String path;
  final String contentHash;
  final int byteSize;
  final String kind;
  final String? displayName;
  final String? mediaType;
}

final class ConfigAssetSyncTarget {
  const ConfigAssetSyncTarget({required this.key, required this.asset});

  final E2eeConfigAssetKey key;
  final MaterializedConfigAsset? asset;
}

/// 配置 Provider 只描述资产槽，文件所有权与密文上传由内容运行时集中管理。
abstract interface class ConfigAssetSyncWriteExecutor
    implements SyncWriteExecutor {
  Future<List<MaterializedConfigAsset>> materializeLocalConfigAssets(
    Iterable<LocalConfigAssetInput> assets,
  );

  Future<T> runLocalBatchWithConfigAssets<T>({
    required Iterable<SyncEntityKey> keys,
    required Iterable<ConfigAssetSyncTarget> targets,
    required bool Function(T result) targetWasPersisted,
    required Future<T> Function() write,
  });
}

/// 标识配置业务真相由账户 SQLCipher Vault 持有，Provider 不得再读写明文存储。
abstract interface class E2eeConfigVaultWriteExecutor
    implements SyncWriteExecutor {}

bool usesE2eeConfigVault(SyncWriteExecutor executor) =>
    executor is E2eeConfigVaultWriteExecutor;

final class LocalOnlySyncWriteExecutor implements SyncWriteExecutor {
  const LocalOnlySyncWriteExecutor();

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return Future<T>.sync(write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    return Future<T>.sync(write);
  }
}

final class UntrackedSyncWriteExecutor implements SyncWriteExecutor {
  const UntrackedSyncWriteExecutor.forTests();

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return write();
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    return write();
  }
}
