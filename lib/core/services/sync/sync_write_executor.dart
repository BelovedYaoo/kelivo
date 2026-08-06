import 'dart:async';

import '../../models/chat_message.dart';
import 'sync_codec.dart';

const int syncImportEntityBatchLimit = 100;

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

/// 大型导入按固定上限分批准备意图，但所有批次与业务写入仍共用一个事务。
abstract interface class ImportSyncWriteExecutor implements SyncWriteExecutor {
  Future<T> runLocalImportBatches<T>({
    required Stream<List<SyncEntityKey>> keyBatches,
    required Stream<List<String>> attachmentRevisionBatches,
    required Future<T> Function() write,
  });
}

/// 为账户工作区提供结构化附件的内容落盘与事务上传草稿能力。
abstract interface class StructuredAttachmentSyncWriteExecutor
    implements SyncWriteExecutor {
  Future<List<ChatMessageAttachment>> materializeLocalAttachments(
    Iterable<ChatMessageAttachment> attachments,
  );

  Future<T> runLocalBatchWithMessageAttachments<T>({
    required Iterable<SyncEntityKey> keys,
    required String targetRevisionId,
    required Iterable<ChatMessageAttachment> attachments,
    required bool Function(T result) targetWasPersisted,
    required Future<T> Function() write,
  });
}

/// 标识配置业务真相由账户 SQLCipher Vault 持有，Provider 不得再读写明文存储。
abstract interface class E2eeConfigVaultWriteExecutor
    implements SyncWriteExecutor {}

bool usesE2eeConfigVault(SyncWriteExecutor executor) =>
    executor is E2eeConfigVaultWriteExecutor;

final class LocalOnlySyncWriteExecutor implements ImportSyncWriteExecutor {
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

  @override
  Future<T> runLocalImportBatches<T>({
    required Stream<List<SyncEntityKey>> keyBatches,
    required Stream<List<String>> attachmentRevisionBatches,
    required Future<T> Function() write,
  }) {
    return Future<T>.sync(write);
  }
}

final class UntrackedSyncWriteExecutor implements ImportSyncWriteExecutor {
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

  @override
  Future<T> runLocalImportBatches<T>({
    required Stream<List<SyncEntityKey>> keyBatches,
    required Stream<List<String>> attachmentRevisionBatches,
    required Future<T> Function() write,
  }) {
    return write();
  }
}
