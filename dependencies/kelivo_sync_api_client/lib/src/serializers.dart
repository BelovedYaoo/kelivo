//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:kelivo_sync_api_client/src/date_serializer.dart';
import 'package:kelivo_sync_api_client/src/model/date.dart';

import 'package:kelivo_sync_api_client/src/model/admin_device_summary.dart';
import 'package:kelivo_sync_api_client/src/model/admin_device_user_summary.dart';
import 'package:kelivo_sync_api_client/src/model/admin_user_summary.dart';
import 'package:kelivo_sync_api_client/src/model/attachment_info.dart';
import 'package:kelivo_sync_api_client/src/model/auth_device_summary.dart';
import 'package:kelivo_sync_api_client/src/model/auth_session_data.dart';
import 'package:kelivo_sync_api_client/src/model/bootstrap_owner_data.dart';
import 'package:kelivo_sync_api_client/src/model/bootstrap_owner_request.dart';
import 'package:kelivo_sync_api_client/src/model/bootstrap_owner_response.dart';
import 'package:kelivo_sync_api_client/src/model/complete_attachment_upload_data.dart';
import 'package:kelivo_sync_api_client/src/model/complete_attachment_upload_request.dart';
import 'package:kelivo_sync_api_client/src/model/complete_attachment_upload_response.dart';
import 'package:kelivo_sync_api_client/src/model/create_admin_user_data.dart';
import 'package:kelivo_sync_api_client/src/model/create_admin_user_request.dart';
import 'package:kelivo_sync_api_client/src/model/create_admin_user_response.dart';
import 'package:kelivo_sync_api_client/src/model/create_auth_session_request.dart';
import 'package:kelivo_sync_api_client/src/model/create_auth_session_response.dart';
import 'package:kelivo_sync_api_client/src/model/delete_attachment_info_data.dart';
import 'package:kelivo_sync_api_client/src/model/delete_attachment_info_request.dart';
import 'package:kelivo_sync_api_client/src/model/delete_attachment_info_response.dart';
import 'package:kelivo_sync_api_client/src/model/device_session_summary.dart';
import 'package:kelivo_sync_api_client/src/model/error_response.dart';
import 'package:kelivo_sync_api_client/src/model/error_response_error.dart';
import 'package:kelivo_sync_api_client/src/model/get_attachment_download_url_data.dart';
import 'package:kelivo_sync_api_client/src/model/get_attachment_download_url_request.dart';
import 'package:kelivo_sync_api_client/src/model/get_attachment_download_url_response.dart';
import 'package:kelivo_sync_api_client/src/model/list_admin_devices_data.dart';
import 'package:kelivo_sync_api_client/src/model/list_admin_devices_request.dart';
import 'package:kelivo_sync_api_client/src/model/list_admin_devices_response.dart';
import 'package:kelivo_sync_api_client/src/model/list_admin_users_data.dart';
import 'package:kelivo_sync_api_client/src/model/list_admin_users_request.dart';
import 'package:kelivo_sync_api_client/src/model/list_admin_users_response.dart';
import 'package:kelivo_sync_api_client/src/model/list_attachment_info_data.dart';
import 'package:kelivo_sync_api_client/src/model/list_attachment_info_request.dart';
import 'package:kelivo_sync_api_client/src/model/list_attachment_info_response.dart';
import 'package:kelivo_sync_api_client/src/model/list_device_sessions_data.dart';
import 'package:kelivo_sync_api_client/src/model/list_device_sessions_request.dart';
import 'package:kelivo_sync_api_client/src/model/list_device_sessions_response.dart';
import 'package:kelivo_sync_api_client/src/model/prepare_attachment_upload_data.dart';
import 'package:kelivo_sync_api_client/src/model/prepare_attachment_upload_request.dart';
import 'package:kelivo_sync_api_client/src/model/prepare_attachment_upload_response.dart';
import 'package:kelivo_sync_api_client/src/model/pull_sync_changes_response.dart';
import 'package:kelivo_sync_api_client/src/model/pull_sync_snapshot_response.dart';
import 'package:kelivo_sync_api_client/src/model/push_sync_changes_response.dart';
import 'package:kelivo_sync_api_client/src/model/reset_admin_user_password_data.dart';
import 'package:kelivo_sync_api_client/src/model/reset_admin_user_password_request.dart';
import 'package:kelivo_sync_api_client/src/model/reset_admin_user_password_response.dart';
import 'package:kelivo_sync_api_client/src/model/revoke_admin_device_data.dart';
import 'package:kelivo_sync_api_client/src/model/revoke_admin_device_request.dart';
import 'package:kelivo_sync_api_client/src/model/revoke_admin_device_response.dart';
import 'package:kelivo_sync_api_client/src/model/revoke_device_session_data.dart';
import 'package:kelivo_sync_api_client/src/model/revoke_device_session_request.dart';
import 'package:kelivo_sync_api_client/src/model/revoke_device_session_response.dart';
import 'package:kelivo_sync_api_client/src/model/sync_applied_mutation_result.dart';
import 'package:kelivo_sync_api_client/src/model/sync_change.dart';
import 'package:kelivo_sync_api_client/src/model/sync_conflict_mutation_result.dart';
import 'package:kelivo_sync_api_client/src/model/sync_create_mutation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_delete_change.dart';
import 'package:kelivo_sync_api_client/src/model/sync_delete_mutation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_entity_type.dart';
import 'package:kelivo_sync_api_client/src/model/sync_mutation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_mutation_result.dart';
import 'package:kelivo_sync_api_client/src/model/sync_patch_operation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_patch_remove_operation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_patch_value_operation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_pull_request.dart';
import 'package:kelivo_sync_api_client/src/model/sync_pull_response_data.dart';
import 'package:kelivo_sync_api_client/src/model/sync_push_request.dart';
import 'package:kelivo_sync_api_client/src/model/sync_push_response_data.dart';
import 'package:kelivo_sync_api_client/src/model/sync_record.dart';
import 'package:kelivo_sync_api_client/src/model/sync_rejected_mutation_result.dart';
import 'package:kelivo_sync_api_client/src/model/sync_restore_mutation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_retry_mutation_result.dart';
import 'package:kelivo_sync_api_client/src/model/sync_snapshot_request.dart';
import 'package:kelivo_sync_api_client/src/model/sync_snapshot_response_data.dart';
import 'package:kelivo_sync_api_client/src/model/sync_update_mutation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_upsert_change.dart';
import 'package:kelivo_sync_api_client/src/model/system_health_data.dart';
import 'package:kelivo_sync_api_client/src/model/system_health_response.dart';
import 'package:kelivo_sync_api_client/src/model/update_admin_user_data.dart';
import 'package:kelivo_sync_api_client/src/model/update_admin_user_quota_request.dart';
import 'package:kelivo_sync_api_client/src/model/update_admin_user_quota_response.dart';
import 'package:kelivo_sync_api_client/src/model/update_admin_user_status_request.dart';
import 'package:kelivo_sync_api_client/src/model/update_admin_user_status_response.dart';
import 'package:kelivo_sync_api_client/src/model/update_auth_password_data.dart';
import 'package:kelivo_sync_api_client/src/model/update_auth_password_request.dart';
import 'package:kelivo_sync_api_client/src/model/update_auth_password_response.dart';
import 'package:kelivo_sync_api_client/src/model/user_summary.dart';

part 'serializers.g.dart';

@SerializersFor([
  AdminDeviceSummary,
  AdminDeviceUserSummary,
  AdminUserSummary,
  AttachmentInfo,
  AuthDeviceSummary,
  AuthSessionData,
  BootstrapOwnerData,
  BootstrapOwnerRequest,
  BootstrapOwnerResponse,
  CompleteAttachmentUploadData,
  CompleteAttachmentUploadRequest,
  CompleteAttachmentUploadResponse,
  CreateAdminUserData,
  CreateAdminUserRequest,
  CreateAdminUserResponse,
  CreateAuthSessionRequest,
  CreateAuthSessionResponse,
  DeleteAttachmentInfoData,
  DeleteAttachmentInfoRequest,
  DeleteAttachmentInfoResponse,
  DeviceSessionSummary,
  ErrorResponse,
  ErrorResponseError,
  GetAttachmentDownloadUrlData,
  GetAttachmentDownloadUrlRequest,
  GetAttachmentDownloadUrlResponse,
  ListAdminDevicesData,
  ListAdminDevicesRequest,
  ListAdminDevicesResponse,
  ListAdminUsersData,
  ListAdminUsersRequest,
  ListAdminUsersResponse,
  ListAttachmentInfoData,
  ListAttachmentInfoRequest,
  ListAttachmentInfoResponse,
  ListDeviceSessionsData,
  ListDeviceSessionsRequest,
  ListDeviceSessionsResponse,
  PrepareAttachmentUploadData,
  PrepareAttachmentUploadRequest,
  PrepareAttachmentUploadResponse,
  PullSyncChangesResponse,
  PullSyncSnapshotResponse,
  PushSyncChangesResponse,
  ResetAdminUserPasswordData,
  ResetAdminUserPasswordRequest,
  ResetAdminUserPasswordResponse,
  RevokeAdminDeviceData,
  RevokeAdminDeviceRequest,
  RevokeAdminDeviceResponse,
  RevokeDeviceSessionData,
  RevokeDeviceSessionRequest,
  RevokeDeviceSessionResponse,
  SyncAppliedMutationResult,
  SyncChange,
  SyncConflictMutationResult,
  SyncCreateMutation,
  SyncDeleteChange,
  SyncDeleteMutation,
  SyncEntityType,
  SyncMutation,
  SyncMutationResult,
  SyncPatchOperation,
  SyncPatchRemoveOperation,
  SyncPatchValueOperation,
  SyncPullRequest,
  SyncPullResponseData,
  SyncPushRequest,
  SyncPushResponseData,
  SyncRecord,
  SyncRejectedMutationResult,
  SyncRestoreMutation,
  SyncRetryMutationResult,
  SyncSnapshotRequest,
  SyncSnapshotResponseData,
  SyncUpdateMutation,
  SyncUpsertChange,
  SystemHealthData,
  SystemHealthResponse,
  UpdateAdminUserData,
  UpdateAdminUserQuotaRequest,
  UpdateAdminUserQuotaResponse,
  UpdateAdminUserStatusRequest,
  UpdateAdminUserStatusResponse,
  UpdateAuthPasswordData,
  UpdateAuthPasswordRequest,
  UpdateAuthPasswordResponse,
  UserSummary,
])
Serializers serializers =
    (_$serializers.toBuilder()
          ..add(const OneOfSerializer())
          ..add(const AnyOfSerializer())
          ..add(const DateSerializer())
          ..add(Iso8601DateTimeSerializer()))
        .build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
