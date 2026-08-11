import '../../../core/services/sync/cloud_sync_types.dart';
import '../../../core/services/sync/e2ee_account_authenticator.dart';
import '../../../core/services/sync/e2ee_account_recovery_runner.dart';
import '../../../core/services/sync/sensitive_utf8.dart';
import '../../../l10n/app_localizations.dart';

String cloudSyncFailureText(AppLocalizations l10n, CloudSyncException error) {
  final protocolMessage = switch (error.serverCode) {
    'AUTH_REGISTRATION_CONFLICT' =>
      l10n.cloudSyncFailureAccountAlreadyRegistered,
    'AUTH_DEVICE_PAIRING_CONFLICT' =>
      l10n.cloudSyncFailureDevicePairingConflict,
    'ACCOUNT_RECOVERY_STATE_CONFLICT' =>
      l10n.cloudSyncFailureAccountRecoveryStateConflict,
    'ACCOUNT_RECOVERY_EXPIRED' => l10n.cloudSyncFailureAccountRecoveryExpired,
    e2eeAccountRecoveryAuthGenerationInvalidCode =>
      l10n.cloudSyncFailureAccountRecoveryStateConflict,
    e2eeAccountRecoveryDeviceAlreadyAuthenticatedCode =>
      l10n.cloudSyncFailureAccountRecoveryDeviceAlreadyAuthenticated,
    'SYNC_SESSION_ALREADY_ACTIVE' => l10n.cloudSyncFailureSessionAlreadyActive,
    'SYNC_LOCAL_DEVICE_WIPE_UNSUPPORTED' =>
      l10n.cloudSyncCurrentDeviceRemovalUnavailable,
    e2eeRecoveryPassphraseMatchesPasswordCode =>
      l10n.cloudSyncRecoveryPassphraseMatchesPassword,
    e2eePendingRegistrationExportRequiredCode =>
      l10n.cloudSyncPendingRegistrationExportMessage,
    e2eePendingRegistrationSubmitRequiredCode =>
      l10n.cloudSyncPendingRegistrationSubmitMessage,
    e2eePendingRegistrationLoginRequiredCode =>
      l10n.cloudSyncFailureRegistrationRecoveryLoginRequired,
    e2eePendingRegistrationUnsupportedCode =>
      l10n.cloudSyncPendingRegistrationUnsupportedMessage,
    e2eeAccountRecoveryUnsupportedCode =>
      l10n.cloudSyncAccountRecoveryUnavailable,
    e2eeAccountRecoveryMediaInvalidCode =>
      l10n.cloudSyncAccountRecoveryMediaInvalid,
    _ => null,
  };
  if (protocolMessage != null) return protocolMessage;
  return switch (error.kind) {
    CloudSyncFailureKind.invalidBaseUrl => l10n.cloudSyncFailureInvalidBaseUrl,
    CloudSyncFailureKind.unauthenticated =>
      l10n.cloudSyncFailureUnauthenticated,
    CloudSyncFailureKind.forbidden => l10n.cloudSyncFailureForbidden,
    CloudSyncFailureKind.notFound => l10n.cloudSyncFailureNotFound,
    CloudSyncFailureKind.conflict => l10n.cloudSyncFailureConflict,
    CloudSyncFailureKind.validation => l10n.cloudSyncFailureValidation,
    CloudSyncFailureKind.rateLimited => l10n.cloudSyncFailureRateLimited,
    CloudSyncFailureKind.server => l10n.cloudSyncFailureServer,
    CloudSyncFailureKind.network => l10n.cloudSyncFailureNetwork,
    CloudSyncFailureKind.timeout => l10n.cloudSyncFailureTimeout,
    CloudSyncFailureKind.cancelled => l10n.cloudSyncFailureCancelled,
    CloudSyncFailureKind.invalidResponse =>
      l10n.cloudSyncFailureInvalidResponse,
    CloudSyncFailureKind.unknown => l10n.cloudSyncFailureUnknown,
  };
}
