import 'config_sync_keys.dart';
import 'e2ee_attachment_manifest.dart';
import 'sync_codec.dart';

const _configAssetRemoteIdentityKeys = <String>{
  'attachmentId',
  'uploadId',
  'chunkKeyEpoch',
  'manifestKeyEpoch',
  'manifestRevision',
  'kind',
};
final _configAssetUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

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

final class E2eeConfigAssetRemoteIdentity {
  E2eeConfigAssetRemoteIdentity({
    required String attachmentId,
    required String uploadId,
    required int chunkKeyEpoch,
    required int manifestKeyEpoch,
    required int manifestRevision,
    required this.kind,
  }) : attachmentId = _requireConfigAssetUuid(attachmentId, 'attachmentId'),
       uploadId = _requireConfigAssetUuid(uploadId, 'uploadId'),
       chunkKeyEpoch = _requireConfigAssetEpoch(chunkKeyEpoch, 'chunkKeyEpoch'),
       manifestKeyEpoch = _requireConfigAssetEpoch(
         manifestKeyEpoch,
         'manifestKeyEpoch',
       ),
       manifestRevision = _requireConfigAssetEpoch(
         manifestRevision,
         'manifestRevision',
       ) {
    if (this.attachmentId == this.uploadId) {
      throw const FormatException('配置资产远端标识不得相同');
    }
    if (this.manifestKeyEpoch - this.chunkKeyEpoch !=
        this.manifestRevision - 1) {
      throw const FormatException('配置资产代次与修订关系无效');
    }
  }

  factory E2eeConfigAssetRemoteIdentity.fromPayload(
    Object? value, {
    required E2eeAttachmentKind expectedKind,
  }) {
    if (value is! Map<String, Object?> ||
        value.length != _configAssetRemoteIdentityKeys.length ||
        !value.keys.every(_configAssetRemoteIdentityKeys.contains)) {
      throw const FormatException('配置资产远端身份字段不匹配');
    }
    final attachmentId = value['attachmentId'];
    final uploadId = value['uploadId'];
    final chunkKeyEpoch = value['chunkKeyEpoch'];
    final manifestKeyEpoch = value['manifestKeyEpoch'];
    final manifestRevision = value['manifestRevision'];
    final kind = value['kind'];
    if (attachmentId is! String ||
        uploadId is! String ||
        chunkKeyEpoch is! int ||
        manifestKeyEpoch is! int ||
        manifestRevision is! int ||
        kind != expectedKind.name) {
      throw const FormatException('配置资产远端身份值无效');
    }
    return E2eeConfigAssetRemoteIdentity(
      attachmentId: attachmentId,
      uploadId: uploadId,
      chunkKeyEpoch: chunkKeyEpoch,
      manifestKeyEpoch: manifestKeyEpoch,
      manifestRevision: manifestRevision,
      kind: expectedKind,
    );
  }

  final String attachmentId;
  final String uploadId;
  final int chunkKeyEpoch;
  final int manifestKeyEpoch;
  final int manifestRevision;
  final E2eeAttachmentKind kind;

  Map<String, Object?> toPayload() => <String, Object?>{
    'attachmentId': attachmentId,
    'uploadId': uploadId,
    'chunkKeyEpoch': chunkKeyEpoch,
    'manifestKeyEpoch': manifestKeyEpoch,
    'manifestRevision': manifestRevision,
    'kind': kind.name,
  };
}

String _requireConfigAssetUuid(String value, String name) {
  if (!_configAssetUuidPattern.hasMatch(value)) {
    throw FormatException('$name 不是规范 UUID v4');
  }
  return value;
}

int _requireConfigAssetEpoch(int value, String name) {
  if (value < 1 || value > 0xffffffff) {
    throw FormatException('$name 必须位于正 uint32 范围');
  }
  return value;
}
