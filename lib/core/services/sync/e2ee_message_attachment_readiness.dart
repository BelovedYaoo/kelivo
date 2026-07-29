import '../../database/chat_database_repository.dart';
import 'e2ee_sync_payload_codec.dart';
import 'e2ee_sync_pull_types.dart';

abstract interface class E2eeMessageAttachmentReadiness {
  Future<List<MessageAssetRegistration>> requireReadyForApply(
    E2eeSyncPulledValueChange messageChange,
  );
}

final class E2eeNoAttachmentMessageReadiness
    implements E2eeMessageAttachmentReadiness {
  const E2eeNoAttachmentMessageReadiness();

  @override
  Future<List<MessageAssetRegistration>> requireReadyForApply(
    E2eeSyncPulledValueChange messageChange,
  ) async {
    if (messageChange.state.entityKey.entityType !=
        E2eeSyncChatRecordTypes.message) {
      throw StateError('sync_attachment_readiness_requires_message');
    }
    final attachments = messageChange.payload['attachments'];
    if (attachments is! List<Object?>) {
      throw const FormatException('message.attachments 必须为数组');
    }
    if (attachments.isNotEmpty) {
      throw StateError('sync_message_attachments_not_configured');
    }
    return const <MessageAssetRegistration>[];
  }
}
