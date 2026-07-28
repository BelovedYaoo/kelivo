import 'e2ee_account_record_state.dart';

const _maximumPositiveInt63 = 0x7fffffffffffffff;

/// 该元数据由服务器分配，只能用于同步进度，不能视为密文认证内容。
final class E2eeSyncUntrustedServerMetadata {
  E2eeSyncUntrustedServerMetadata({
    required this.changeSeq,
    required this.revision,
  }) {
    if (changeSeq < 0 || changeSeq > _maximumPositiveInt63) {
      throw const FormatException('服务端 changeSeq 超出非负 int63 范围');
    }
    if (revision < 1 || revision > _maximumPositiveInt63) {
      throw const FormatException('服务端 revision 超出正 int63 范围');
    }
  }

  final int changeSeq;
  final int revision;
}

sealed class E2eeSyncPulledChange {
  const E2eeSyncPulledChange({
    required this.untrustedServerMetadata,
    required this.state,
  });

  final E2eeSyncUntrustedServerMetadata untrustedServerMetadata;
  final E2eeAuthenticatedAccountRecordState state;
}

final class E2eeSyncPulledValueChange extends E2eeSyncPulledChange {
  const E2eeSyncPulledValueChange({
    required super.untrustedServerMetadata,
    required super.state,
    required this.payload,
  });

  final Map<String, Object?> payload;
}

final class E2eeSyncPulledTombstoneChange extends E2eeSyncPulledChange {
  const E2eeSyncPulledTombstoneChange({
    required super.untrustedServerMetadata,
    required super.state,
  });
}

/// 回调必须只操作当前 ChatDatabaseRepository 所属 SQL 事务内的业务表。
typedef E2eeSyncTransactionalBusinessApplier =
    Future<void> Function(List<E2eeSyncPulledChange> applicableChanges);
