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
          ..add(AuthDeviceSummary.serializer)
          ..add(AuthDeviceSummaryPlatformEnum.serializer)
          ..add(AuthSessionData.serializer)
          ..add(BootstrapOwnerData.serializer)
          ..add(BootstrapOwnerRequest.serializer)
          ..add(BootstrapOwnerResponse.serializer)
          ..add(CreateAdminUserData.serializer)
          ..add(CreateAdminUserRequest.serializer)
          ..add(CreateAdminUserRequestRoleEnum.serializer)
          ..add(CreateAdminUserResponse.serializer)
          ..add(CreateAuthSessionRequest.serializer)
          ..add(CreateAuthSessionRequestPlatformEnum.serializer)
          ..add(CreateAuthSessionResponse.serializer)
          ..add(DeviceSessionSummary.serializer)
          ..add(DeviceSessionSummaryPlatformEnum.serializer)
          ..add(DeviceSessionSummaryStatusEnum.serializer)
          ..add(ErrorResponse.serializer)
          ..add(ErrorResponseError.serializer)
          ..add(ListAdminDevicesData.serializer)
          ..add(ListAdminDevicesRequest.serializer)
          ..add(ListAdminDevicesRequestStatusEnum.serializer)
          ..add(ListAdminDevicesResponse.serializer)
          ..add(ListAdminUsersData.serializer)
          ..add(ListAdminUsersRequest.serializer)
          ..add(ListAdminUsersRequestRoleEnum.serializer)
          ..add(ListAdminUsersRequestStatusEnum.serializer)
          ..add(ListAdminUsersResponse.serializer)
          ..add(ListDeviceSessionsData.serializer)
          ..add(ListDeviceSessionsRequest.serializer)
          ..add(ListDeviceSessionsRequestStatusEnum.serializer)
          ..add(ListDeviceSessionsResponse.serializer)
          ..add(PullEncryptedSyncChangesResponse.serializer)
          ..add(PullEncryptedSyncSnapshotResponse.serializer)
          ..add(PushEncryptedSyncRecordsResponse.serializer)
          ..add(ResetAdminUserPasswordData.serializer)
          ..add(ResetAdminUserPasswordRequest.serializer)
          ..add(ResetAdminUserPasswordResponse.serializer)
          ..add(RevokeAdminDeviceData.serializer)
          ..add(RevokeAdminDeviceRequest.serializer)
          ..add(RevokeAdminDeviceResponse.serializer)
          ..add(RevokeDeviceSessionData.serializer)
          ..add(RevokeDeviceSessionRequest.serializer)
          ..add(RevokeDeviceSessionResponse.serializer)
          ..add(SyncActiveRecord.serializer)
          ..add(SyncAppliedMutationResult.serializer)
          ..add(SyncAppliedMutationResultStatusEnum.serializer)
          ..add(SyncChange.serializer)
          ..add(SyncConflictMutationResult.serializer)
          ..add(SyncConflictMutationResultStatusEnum.serializer)
          ..add(SyncDeleteChange.serializer)
          ..add(SyncDeleteChangeOperationEnum.serializer)
          ..add(SyncDeleteMutation.serializer)
          ..add(SyncDeleteMutationOperationEnum.serializer)
          ..add(SyncDeletedRecord.serializer)
          ..add(SyncMutation.serializer)
          ..add(SyncMutationResult.serializer)
          ..add(SyncPullRequest.serializer)
          ..add(SyncPullResponseData.serializer)
          ..add(SyncPushRequest.serializer)
          ..add(SyncPushResponseData.serializer)
          ..add(SyncPutChange.serializer)
          ..add(SyncPutChangeOperationEnum.serializer)
          ..add(SyncPutMutation.serializer)
          ..add(SyncPutMutationOperationEnum.serializer)
          ..add(SyncRecord.serializer)
          ..add(SyncRejectedMutationResult.serializer)
          ..add(SyncRejectedMutationResultStatusEnum.serializer)
          ..add(SyncSnapshotRequest.serializer)
          ..add(SyncSnapshotResponseData.serializer)
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
            const FullType(BuiltList, const [
              const FullType(DeviceSessionSummary),
            ]),
            () => ListBuilder<DeviceSessionSummary>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(SyncChange)]),
            () => ListBuilder<SyncChange>(),
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
            const FullType(BuiltList, const [const FullType(SyncRecord)]),
            () => ListBuilder<SyncRecord>(),
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
