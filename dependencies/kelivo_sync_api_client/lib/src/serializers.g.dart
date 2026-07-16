// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serializers.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializers _$serializers =
    (Serializers().toBuilder()
          ..add(AdminDeviceSummary.serializer)
          ..add(AdminDeviceSummaryPlatformEnum.serializer)
          ..add(AdminDeviceSummaryStatusEnum.serializer)
          ..add(AdminDeviceUserSummary.serializer)
          ..add(AdminDeviceUserSummaryRoleEnum.serializer)
          ..add(AdminUserSummary.serializer)
          ..add(AdminUserSummaryRoleEnum.serializer)
          ..add(AdminUserSummaryStatusEnum.serializer)
          ..add(AttachmentInfo.serializer)
          ..add(AuthDeviceSummary.serializer)
          ..add(AuthDeviceSummaryPlatformEnum.serializer)
          ..add(AuthSessionData.serializer)
          ..add(BootstrapOwnerData.serializer)
          ..add(BootstrapOwnerRequest.serializer)
          ..add(BootstrapOwnerResponse.serializer)
          ..add(CompleteAttachmentUploadData.serializer)
          ..add(CompleteAttachmentUploadRequest.serializer)
          ..add(CompleteAttachmentUploadResponse.serializer)
          ..add(CreateAdminUserData.serializer)
          ..add(CreateAdminUserRequest.serializer)
          ..add(CreateAdminUserRequestRoleEnum.serializer)
          ..add(CreateAdminUserResponse.serializer)
          ..add(CreateAuthSessionRequest.serializer)
          ..add(CreateAuthSessionRequestPlatformEnum.serializer)
          ..add(CreateAuthSessionResponse.serializer)
          ..add(DeleteAttachmentInfoData.serializer)
          ..add(DeleteAttachmentInfoRequest.serializer)
          ..add(DeleteAttachmentInfoResponse.serializer)
          ..add(DeviceSessionSummary.serializer)
          ..add(DeviceSessionSummaryPlatformEnum.serializer)
          ..add(DeviceSessionSummaryStatusEnum.serializer)
          ..add(ErrorResponse.serializer)
          ..add(ErrorResponseError.serializer)
          ..add(GetAttachmentDownloadUrlData.serializer)
          ..add(GetAttachmentDownloadUrlRequest.serializer)
          ..add(GetAttachmentDownloadUrlResponse.serializer)
          ..add(ListAdminDevicesData.serializer)
          ..add(ListAdminDevicesRequest.serializer)
          ..add(ListAdminDevicesRequestStatusEnum.serializer)
          ..add(ListAdminDevicesResponse.serializer)
          ..add(ListAdminUsersData.serializer)
          ..add(ListAdminUsersRequest.serializer)
          ..add(ListAdminUsersRequestRoleEnum.serializer)
          ..add(ListAdminUsersRequestStatusEnum.serializer)
          ..add(ListAdminUsersResponse.serializer)
          ..add(ListAttachmentInfoData.serializer)
          ..add(ListAttachmentInfoRequest.serializer)
          ..add(ListAttachmentInfoResponse.serializer)
          ..add(ListDeviceSessionsData.serializer)
          ..add(ListDeviceSessionsRequest.serializer)
          ..add(ListDeviceSessionsRequestStatusEnum.serializer)
          ..add(ListDeviceSessionsResponse.serializer)
          ..add(ListSyncConflictsRequest.serializer)
          ..add(ListSyncConflictsRequestStateEnum.serializer)
          ..add(ListSyncConflictsResponse.serializer)
          ..add(ListSyncConflictsResponseData.serializer)
          ..add(PrepareAttachmentUploadData.serializer)
          ..add(PrepareAttachmentUploadDataUploadMethodEnum.serializer)
          ..add(PrepareAttachmentUploadRequest.serializer)
          ..add(PrepareAttachmentUploadResponse.serializer)
          ..add(PullSyncChangesResponse.serializer)
          ..add(PullSyncSnapshotResponse.serializer)
          ..add(PushSyncChangesResponse.serializer)
          ..add(ResetAdminUserPasswordData.serializer)
          ..add(ResetAdminUserPasswordRequest.serializer)
          ..add(ResetAdminUserPasswordResponse.serializer)
          ..add(ResolveSyncConflictRequest.serializer)
          ..add(ResolveSyncConflictResponse.serializer)
          ..add(ResolveSyncConflictResponseData.serializer)
          ..add(RevokeAdminDeviceData.serializer)
          ..add(RevokeAdminDeviceRequest.serializer)
          ..add(RevokeAdminDeviceResponse.serializer)
          ..add(RevokeDeviceSessionData.serializer)
          ..add(RevokeDeviceSessionRequest.serializer)
          ..add(RevokeDeviceSessionResponse.serializer)
          ..add(SyncAppliedMutationResult.serializer)
          ..add(SyncAppliedMutationResultStatusEnum.serializer)
          ..add(SyncChange.serializer)
          ..add(SyncConflict.serializer)
          ..add(SyncConflictDetails.serializer)
          ..add(SyncConflictDetailsFieldsInner.serializer)
          ..add(SyncConflictDetailsFieldsInnerCurrent.serializer)
          ..add(SyncConflictMutationResult.serializer)
          ..add(SyncConflictMutationResultReasonEnum.serializer)
          ..add(SyncConflictMutationResultStatusEnum.serializer)
          ..add(SyncConflictStateEnum.serializer)
          ..add(SyncCreateMutation.serializer)
          ..add(SyncCreateMutationOperationEnum.serializer)
          ..add(SyncDeleteChange.serializer)
          ..add(SyncDeleteChangeOperationEnum.serializer)
          ..add(SyncDeleteMutation.serializer)
          ..add(SyncDeleteMutationOperationEnum.serializer)
          ..add(SyncEntityType.serializer)
          ..add(SyncFieldConflictMutationResult.serializer)
          ..add(SyncFieldConflictMutationResultReasonEnum.serializer)
          ..add(SyncFieldConflictMutationResultStatusEnum.serializer)
          ..add(SyncMutation.serializer)
          ..add(SyncMutationResult.serializer)
          ..add(SyncPatchOperation.serializer)
          ..add(SyncPatchRemoveOperation.serializer)
          ..add(SyncPatchRemoveOperationOpEnum.serializer)
          ..add(SyncPatchValueOperation.serializer)
          ..add(SyncPatchValueOperationOpEnum.serializer)
          ..add(SyncPullRequest.serializer)
          ..add(SyncPullResponseData.serializer)
          ..add(SyncPushRequest.serializer)
          ..add(SyncPushResponseData.serializer)
          ..add(SyncRecord.serializer)
          ..add(SyncRejectedMutationResult.serializer)
          ..add(SyncRejectedMutationResultStatusEnum.serializer)
          ..add(SyncRestoreMutation.serializer)
          ..add(SyncRestoreMutationOperationEnum.serializer)
          ..add(SyncRetryMutationResult.serializer)
          ..add(SyncRetryMutationResultStatusEnum.serializer)
          ..add(SyncSnapshotRequest.serializer)
          ..add(SyncSnapshotResponseData.serializer)
          ..add(SyncUpdateMutation.serializer)
          ..add(SyncUpdateMutationOperationEnum.serializer)
          ..add(SyncUpsertChange.serializer)
          ..add(SyncUpsertChangeOperationEnum.serializer)
          ..add(SystemHealthData.serializer)
          ..add(SystemHealthDataServiceEnum.serializer)
          ..add(SystemHealthDataStatusEnum.serializer)
          ..add(SystemHealthResponse.serializer)
          ..add(UpdateAdminUserData.serializer)
          ..add(UpdateAdminUserQuotaRequest.serializer)
          ..add(UpdateAdminUserQuotaResponse.serializer)
          ..add(UpdateAdminUserStatusRequest.serializer)
          ..add(UpdateAdminUserStatusRequestStatusEnum.serializer)
          ..add(UpdateAdminUserStatusResponse.serializer)
          ..add(UpdateAuthPasswordData.serializer)
          ..add(UpdateAuthPasswordRequest.serializer)
          ..add(UpdateAuthPasswordResponse.serializer)
          ..add(UserSummary.serializer)
          ..add(UserSummaryRoleEnum.serializer)
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(AdminDeviceSummary),
            ]),
            () => ListBuilder<AdminDeviceSummary>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(AdminUserSummary)]),
            () => ListBuilder<AdminUserSummary>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(AttachmentInfo)]),
            () => ListBuilder<AttachmentInfo>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(DeviceSessionSummary),
            ]),
            () => ListBuilder<DeviceSessionSummary>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(String)]),
            () => ListBuilder<String>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(SyncChange)]),
            () => ListBuilder<SyncChange>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(SyncConflict)]),
            () => ListBuilder<SyncConflict>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(SyncConflictDetailsFieldsInner),
            ]),
            () => ListBuilder<SyncConflictDetailsFieldsInner>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(SyncMutation)]),
            () => ListBuilder<SyncMutation>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(SyncMutationResult),
            ]),
            () => ListBuilder<SyncMutationResult>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(SyncPatchOperation),
            ]),
            () => ListBuilder<SyncPatchOperation>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(SyncRecord)]),
            () => ListBuilder<SyncRecord>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltMap, const [
              const FullType(String),
              const FullType(String),
            ]),
            () => MapBuilder<String, String>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltMap, const [
              const FullType(String),
              const FullType.nullable(JsonObject),
            ]),
            () => MapBuilder<String, JsonObject?>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltMap, const [
              const FullType(String),
              const FullType.nullable(JsonObject),
            ]),
            () => MapBuilder<String, JsonObject?>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltMap, const [
              const FullType(String),
              const FullType.nullable(JsonObject),
            ]),
            () => MapBuilder<String, JsonObject?>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltMap, const [
              const FullType(String),
              const FullType.nullable(JsonObject),
            ]),
            () => MapBuilder<String, JsonObject?>(),
          ))
        .build();

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
