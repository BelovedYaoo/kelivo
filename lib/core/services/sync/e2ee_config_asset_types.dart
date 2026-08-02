import 'config_sync_keys.dart';
import 'sync_codec.dart';

enum E2eeConfigAssetSlot {
  avatar('avatar'),
  background('background'),
  appFont('app-font'),
  codeFont('code-font');

  const E2eeConfigAssetSlot(this.wireValue);

  final String wireValue;

  static E2eeConfigAssetSlot fromWireValue(String value) {
    for (final slot in values) {
      if (slot.wireValue == value) return slot;
    }
    throw const FormatException('配置资产槽无效');
  }
}

final class E2eeConfigAssetKey {
  E2eeConfigAssetKey({required this.entityKey, required this.slot}) {
    ConfigSyncKeys.validate(entityKey);
    final allowed = switch (entityKey.entityType) {
      ConfigSyncKeys.assistantType =>
        slot == E2eeConfigAssetSlot.avatar ||
            slot == E2eeConfigAssetSlot.background,
      ConfigSyncKeys.providerType => slot == E2eeConfigAssetSlot.avatar,
      ConfigSyncKeys.preferenceType =>
        entityKey == ConfigSyncKeys.profile &&
            slot == E2eeConfigAssetSlot.avatar,
      _ => false,
    };
    if (!allowed) throw const FormatException('配置实体与资产槽不匹配');
  }

  final SyncEntityKey entityKey;
  final E2eeConfigAssetSlot slot;

  @override
  bool operator ==(Object other) =>
      other is E2eeConfigAssetKey &&
      other.entityKey == entityKey &&
      other.slot == slot;

  @override
  int get hashCode => Object.hash(entityKey, slot);
}
