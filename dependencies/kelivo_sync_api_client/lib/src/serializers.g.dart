// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serializers.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializers _$serializers =
    (Serializers().toBuilder()
          ..add(AccountRecoveryAttemptStartData.serializer)
          ..add(AccountRecoveryAttemptStartDataOneOf.serializer)
          ..add(AccountRecoveryAttemptStartDataOneOf1.serializer)
          ..add(AccountRecoveryAttemptStartDataOneOf1ActionEnum.serializer)
          ..add(AccountRecoveryAttemptStartDataOneOf1NextActionEnum.serializer)
          ..add(AccountRecoveryAttemptStartDataOneOf1ResultEnum.serializer)
          ..add(AccountRecoveryAttemptStartDataOneOf1StatusEnum.serializer)
          ..add(AccountRecoveryAttemptStartDataOneOfActionEnum.serializer)
          ..add(AccountRecoveryAttemptStartDataOneOfResultEnum.serializer)
          ..add(AccountRecoveryAttemptStartRequest.serializer)
          ..add(AccountRecoveryAttemptStartRequestOneOf.serializer)
          ..add(AccountRecoveryAttemptStartRequestOneOf1.serializer)
          ..add(AccountRecoveryAttemptStartRequestOneOf1ActionEnum.serializer)
          ..add(AccountRecoveryAttemptStartRequestOneOfActionEnum.serializer)
          ..add(AccountRecoveryDataState.serializer)
          ..add(AccountRecoveryDataStatePhaseEnum.serializer)
          ..add(AccountRecoveryHistoryListData.serializer)
          ..add(AccountRecoveryHistoryListRequest.serializer)
          ..add(AccountRecoveryMembershipCommitData.serializer)
          ..add(AccountRecoveryMembershipCommitDataNextActionEnum.serializer)
          ..add(AccountRecoveryMembershipCommitDataResultEnum.serializer)
          ..add(AccountRecoveryMembershipCommitDataStatusEnum.serializer)
          ..add(AccountRecoveryReplacementChallengeData.serializer)
          ..add(AccountRecoveryReplacementChallengeDataDataState.serializer)
          ..add(
            AccountRecoveryReplacementChallengeDataDataStatePhaseEnum
                .serializer,
          )
          ..add(AccountRecoveryReplacementChallengeDataDeviceState.serializer)
          ..add(AccountRecoveryReplacementChallengeDataResultEnum.serializer)
          ..add(AccountRecoveryReplacementChallengeDataSecurityState.serializer)
          ..add(AccountRecoveryReplacementChallengeRequest.serializer)
          ..add(AccountRecoveryReplacementCommitRequest.serializer)
          ..add(AccountRecoveryReplacementCommitRequestAuthorization.serializer)
          ..add(
            AccountRecoveryReplacementCommitRequestAuthorizationOneOf
                .serializer,
          )
          ..add(
            AccountRecoveryReplacementCommitRequestAuthorizationOneOf1
                .serializer,
          )
          ..add(
            AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
                .serializer,
          )
          ..add(
            AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
                .serializer,
          )
          ..add(AccountRecoveryResumeCommitRequest.serializer)
          ..add(AccountRecoveryResumeCommitRequestEnvelope.serializer)
          ..add(AccountRecoveryStateData.serializer)
          ..add(AccountRecoveryStateDataNextActionEnum.serializer)
          ..add(AccountRecoveryStateDataStatusEnum.serializer)
          ..add(AccountSecurityStateCurrentProjection.serializer)
          ..add(
            AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum.serializer,
          )
          ..add(AccountSecurityStateData.serializer)
          ..add(AccountSecurityStateDataDataRekeyPhaseEnum.serializer)
          ..add(AccountSecurityStateEnvelope.serializer)
          ..add(AccountSecurityStateHistoryItem.serializer)
          ..add(AdminDeviceSummary.serializer)
          ..add(AdminDeviceSummaryPlatformEnum.serializer)
          ..add(AdminDeviceSummaryStatusEnum.serializer)
          ..add(AdminDeviceUserSummary.serializer)
          ..add(AdminDeviceUserSummaryRoleEnum.serializer)
          ..add(AdminUserSummary.serializer)
          ..add(AdminUserSummaryRoleEnum.serializer)
          ..add(AdminUserSummaryStatusEnum.serializer)
          ..add(AttachmentChunkData.serializer)
          ..add(AttachmentChunkDataDataRekeyPhaseEnum.serializer)
          ..add(AttachmentCommitUploadRequest.serializer)
          ..add(AttachmentCommittedData.serializer)
          ..add(AttachmentCommittedDataStatusEnum.serializer)
          ..add(AttachmentCreateUploadRequest.serializer)
          ..add(AttachmentDeleteRequest.serializer)
          ..add(AttachmentDeletedData.serializer)
          ..add(AttachmentDeletedDataStatusEnum.serializer)
          ..add(AttachmentGetChunkRequest.serializer)
          ..add(AttachmentGetManifestRequest.serializer)
          ..add(AttachmentManifestChunk.serializer)
          ..add(AttachmentManifestData.serializer)
          ..add(AttachmentManifestDataDataRekeyPhaseEnum.serializer)
          ..add(AttachmentPutChunkRequest.serializer)
          ..add(AttachmentStoredChunkData.serializer)
          ..add(AttachmentStoredChunkDataStatusEnum.serializer)
          ..add(AttachmentUploadData.serializer)
          ..add(AttachmentUploadDataStatusEnum.serializer)
          ..add(AuthenticatedSessionData.serializer)
          ..add(AuthenticatedSessionDataResultEnum.serializer)
          ..add(AuthenticatedSessionResponse.serializer)
          ..add(CancelSelfRevocationRequest.serializer)
          ..add(CancelSelfRevocationResponse.serializer)
          ..add(ClaimDataRekeyLeaseResponse.serializer)
          ..add(CommitAccountRecoveryReplacementResponse.serializer)
          ..add(CommitAccountRecoveryResumeResponse.serializer)
          ..add(CommitDeviceRotationData.serializer)
          ..add(CommitDeviceRotationDataDataRekeyPhaseEnum.serializer)
          ..add(CommitDeviceRotationDataResultEnum.serializer)
          ..add(CommitDeviceRotationRequest.serializer)
          ..add(CommitDeviceRotationResponse.serializer)
          ..add(CommitEncryptedAttachmentUploadResponse.serializer)
          ..add(CreateAccountRecoveryReplacementChallengeResponse.serializer)
          ..add(CreateEncryptedAttachmentUploadResponse.serializer)
          ..add(CreateSelfRevocationRequest.serializer)
          ..add(CreateSelfRevocationResponse.serializer)
          ..add(DataRekeyAttachmentStageData.serializer)
          ..add(DataRekeyAttachmentStageDataResultEnum.serializer)
          ..add(DataRekeyAttachmentStageRequest.serializer)
          ..add(DataRekeyCompletionProofData.serializer)
          ..add(
            DataRekeyCompletionProofDataSourceAttachmentCursorEnd.serializer,
          )
          ..add(DataRekeyFinalizeData.serializer)
          ..add(DataRekeyFinalizeRequest.serializer)
          ..add(DataRekeyFinalizeRequestProof.serializer)
          ..add(DataRekeyFinalizedData.serializer)
          ..add(DataRekeyFinalizedDataResultEnum.serializer)
          ..add(DataRekeyLeaseClaimData.serializer)
          ..add(DataRekeyLeaseClaimDataPhaseEnum.serializer)
          ..add(DataRekeyLeaseClaimRequest.serializer)
          ..add(DataRekeyPendingLeaseData.serializer)
          ..add(DataRekeyPendingStateData.serializer)
          ..add(DataRekeyPendingStateDataPhaseEnum.serializer)
          ..add(DataRekeyReadyStateData.serializer)
          ..add(DataRekeyReadyStateDataPhaseEnum.serializer)
          ..add(DataRekeyRecordStageData.serializer)
          ..add(DataRekeyRecordStageDataResultEnum.serializer)
          ..add(DataRekeyRecordStageRequest.serializer)
          ..add(DataRekeySourceAttachmentData.serializer)
          ..add(DataRekeySourceAttachmentDataChunksInner.serializer)
          ..add(DataRekeySourceAttachmentListData.serializer)
          ..add(DataRekeySourceAttachmentListRequest.serializer)
          ..add(DataRekeySourceRecordListData.serializer)
          ..add(DataRekeySourceRecordListDataRecordsInner.serializer)
          ..add(DataRekeySourceRecordListDataRecordsInnerKindEnum.serializer)
          ..add(DataRekeySourceRecordListRequest.serializer)
          ..add(DataRekeyStateData.serializer)
          ..add(DataRekeyVerificationPendingData.serializer)
          ..add(DataRekeyVerificationPendingDataPhaseEnum.serializer)
          ..add(DataRekeyVerificationPendingDataResultEnum.serializer)
          ..add(DeleteEncryptedAttachmentResponse.serializer)
          ..add(DevicePairingApproveData.serializer)
          ..add(DevicePairingApproveDataResultEnum.serializer)
          ..add(DevicePairingApproveRequest.serializer)
          ..add(DevicePairingApproveResponse.serializer)
          ..add(DevicePairingCancelData.serializer)
          ..add(DevicePairingCancelDataResultEnum.serializer)
          ..add(DevicePairingCancelRequest.serializer)
          ..add(DevicePairingCancelResponse.serializer)
          ..add(DevicePairingConsumeData.serializer)
          ..add(DevicePairingConsumeDataResultEnum.serializer)
          ..add(DevicePairingConsumeRequest.serializer)
          ..add(DevicePairingConsumeResponse.serializer)
          ..add(DevicePairingCreateData.serializer)
          ..add(DevicePairingCreateDataTargetDevice.serializer)
          ..add(DevicePairingCreateDataTargetDevicePlatformEnum.serializer)
          ..add(DevicePairingCreateRequest.serializer)
          ..add(DevicePairingCreateResponse.serializer)
          ..add(DevicePairingQueryData.serializer)
          ..add(DevicePairingQueryDataOneOf.serializer)
          ..add(DevicePairingQueryDataOneOf1.serializer)
          ..add(DevicePairingQueryDataOneOf1StatusEnum.serializer)
          ..add(DevicePairingQueryDataOneOfStatusEnum.serializer)
          ..add(DevicePairingQueryRequest.serializer)
          ..add(DevicePairingQueryResponse.serializer)
          ..add(ErrorResponse.serializer)
          ..add(ErrorResponseError.serializer)
          ..add(FinalizeDataRekeyResponse.serializer)
          ..add(GenesisSecurityState.serializer)
          ..add(GetAccountRecoveryStateResponse.serializer)
          ..add(GetDataRekeyStateResponse.serializer)
          ..add(GetDeviceSecurityStateResponse.serializer)
          ..add(GetEncryptedAttachmentChunkResponse.serializer)
          ..add(GetEncryptedAttachmentManifestResponse.serializer)
          ..add(GetSelfRevocationStatusResponse.serializer)
          ..add(ListAccountRecoveryHistoryResponse.serializer)
          ..add(ListAccountSecurityStateHistoryData.serializer)
          ..add(ListAccountSecurityStateHistoryRequest.serializer)
          ..add(ListAdminDevicesData.serializer)
          ..add(ListAdminDevicesRequest.serializer)
          ..add(ListAdminDevicesRequestStatusEnum.serializer)
          ..add(ListAdminDevicesResponse.serializer)
          ..add(ListAdminUsersData.serializer)
          ..add(ListAdminUsersRequest.serializer)
          ..add(ListAdminUsersRequestRoleEnum.serializer)
          ..add(ListAdminUsersRequestStatusEnum.serializer)
          ..add(ListAdminUsersResponse.serializer)
          ..add(ListDataRekeySourceAttachmentsResponse.serializer)
          ..add(ListDataRekeySourceRecordsResponse.serializer)
          ..add(ListDeviceSecurityStateHistoryResponse.serializer)
          ..add(ListSelfRevocationRequestsResponse.serializer)
          ..add(ListTrustedDevicesData.serializer)
          ..add(ListTrustedDevicesRequest.serializer)
          ..add(ListTrustedDevicesRequestStatusEnum.serializer)
          ..add(ListTrustedDevicesResponse.serializer)
          ..add(OpaqueLoginFinishData.serializer)
          ..add(OpaqueLoginFinishDataOneOf.serializer)
          ..add(OpaqueLoginFinishDataOneOf1.serializer)
          ..add(OpaqueLoginFinishDataOneOf1Device.serializer)
          ..add(OpaqueLoginFinishDataOneOf1DevicePlatformEnum.serializer)
          ..add(OpaqueLoginFinishDataOneOf1DeviceStatusEnum.serializer)
          ..add(OpaqueLoginFinishDataOneOf1ResultEnum.serializer)
          ..add(OpaqueLoginFinishDataOneOfResultEnum.serializer)
          ..add(OpaqueLoginFinishRequest.serializer)
          ..add(OpaqueLoginFinishResponse.serializer)
          ..add(OpaqueLoginStartData.serializer)
          ..add(OpaqueLoginStartRequest.serializer)
          ..add(OpaqueLoginStartRequestPlatformEnum.serializer)
          ..add(OpaqueLoginStartResponse.serializer)
          ..add(OpaqueRegistrationFinishData.serializer)
          ..add(OpaqueRegistrationFinishDataDevice.serializer)
          ..add(OpaqueRegistrationFinishDataDevicePlatformEnum.serializer)
          ..add(OpaqueRegistrationFinishDataDeviceStatusEnum.serializer)
          ..add(OpaqueRegistrationFinishDataResultEnum.serializer)
          ..add(OpaqueRegistrationFinishDataUser.serializer)
          ..add(OpaqueRegistrationFinishDataUserRoleEnum.serializer)
          ..add(OpaqueRegistrationFinishRequest.serializer)
          ..add(OpaqueRegistrationFinishResponse.serializer)
          ..add(OpaqueRegistrationStartData.serializer)
          ..add(OpaqueRegistrationStartRequest.serializer)
          ..add(OpaqueRegistrationStartRequestPlatformEnum.serializer)
          ..add(OpaqueRegistrationStartResponse.serializer)
          ..add(PendingSelfRevocationRequest.serializer)
          ..add(PullEncryptedSyncChangesResponse.serializer)
          ..add(PullEncryptedSyncSnapshotResponse.serializer)
          ..add(PushEncryptedSyncRecordsResponse.serializer)
          ..add(PutEncryptedAttachmentChunkResponse.serializer)
          ..add(RevokeAdminDeviceData.serializer)
          ..add(RevokeAdminDeviceRequest.serializer)
          ..add(RevokeAdminDeviceResponse.serializer)
          ..add(SelfRevocationRequestData.serializer)
          ..add(SelfRevocationRequestDataResultEnum.serializer)
          ..add(SelfRevocationRequestDataStatusEnum.serializer)
          ..add(SelfRevocationRequestListData.serializer)
          ..add(SelfRevocationStatusData.serializer)
          ..add(SelfRevocationStatusDataOneOf.serializer)
          ..add(SelfRevocationStatusDataOneOf1.serializer)
          ..add(SelfRevocationStatusDataOneOf1Receipt.serializer)
          ..add(SelfRevocationStatusDataOneOf1StatusEnum.serializer)
          ..add(SelfRevocationStatusDataOneOf2.serializer)
          ..add(SelfRevocationStatusDataOneOf2StatusEnum.serializer)
          ..add(SelfRevocationStatusDataOneOf3.serializer)
          ..add(SelfRevocationStatusDataOneOf3StatusEnum.serializer)
          ..add(SelfRevocationStatusDataOneOf4.serializer)
          ..add(SelfRevocationStatusDataOneOf4StatusEnum.serializer)
          ..add(SelfRevocationStatusDataOneOfStatusEnum.serializer)
          ..add(StageDataRekeyAttachmentResponse.serializer)
          ..add(StageDataRekeyRecordResponse.serializer)
          ..add(StartAccountRecoveryAttemptResponse.serializer)
          ..add(SyncAppliedMutationResult.serializer)
          ..add(SyncAppliedMutationResultStatusEnum.serializer)
          ..add(SyncChange.serializer)
          ..add(SyncChangeOperationEnum.serializer)
          ..add(SyncConflictMutationResult.serializer)
          ..add(SyncConflictMutationResultStatusEnum.serializer)
          ..add(SyncMutation.serializer)
          ..add(SyncMutationOperationEnum.serializer)
          ..add(SyncMutationResult.serializer)
          ..add(SyncPullPageData.serializer)
          ..add(SyncPullPageDataDataRekeyPhaseEnum.serializer)
          ..add(SyncPullRequest.serializer)
          ..add(SyncPullResetData.serializer)
          ..add(SyncPullResetDataDataRekeyPhaseEnum.serializer)
          ..add(SyncPullResetDataNextCursorEnum.serializer)
          ..add(SyncPullResponseData.serializer)
          ..add(SyncPushRequest.serializer)
          ..add(SyncPushResponseData.serializer)
          ..add(SyncRecord.serializer)
          ..add(SyncRejectedMutationResult.serializer)
          ..add(SyncRejectedMutationResultStatusEnum.serializer)
          ..add(SyncSnapshotRequest.serializer)
          ..add(SyncSnapshotResponseData.serializer)
          ..add(SyncSnapshotResponseDataDataRekeyPhaseEnum.serializer)
          ..add(SystemHealthData.serializer)
          ..add(SystemHealthDataServiceEnum.serializer)
          ..add(SystemHealthDataStatusEnum.serializer)
          ..add(SystemHealthResponse.serializer)
          ..add(TrustedDeviceSummary.serializer)
          ..add(TrustedDeviceSummaryPlatformEnum.serializer)
          ..add(TrustedDeviceSummaryStatusEnum.serializer)
          ..add(UnsignedAccountSecurityStateEnvelope.serializer)
          ..add(UpdateAdminUserData.serializer)
          ..add(UpdateAdminUserQuotaRequest.serializer)
          ..add(UpdateAdminUserQuotaResponse.serializer)
          ..add(UpdateAdminUserStatusRequest.serializer)
          ..add(UpdateAdminUserStatusRequestStatusEnum.serializer)
          ..add(UpdateAdminUserStatusResponse.serializer)
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(AccountSecurityStateEnvelope),
            ]),
            () => ListBuilder<AccountSecurityStateEnvelope>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(AccountSecurityStateHistoryItem),
            ]),
            () => ListBuilder<AccountSecurityStateHistoryItem>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(AccountSecurityStateHistoryItem),
            ]),
            () => ListBuilder<AccountSecurityStateHistoryItem>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(AccountSecurityStateHistoryItem),
            ]),
            () => ListBuilder<AccountSecurityStateHistoryItem>(),
          )
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
              const FullType(AttachmentManifestChunk),
            ]),
            () => ListBuilder<AttachmentManifestChunk>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(AttachmentManifestChunk),
            ]),
            () => ListBuilder<AttachmentManifestChunk>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(DataRekeySourceAttachmentData),
            ]),
            () => ListBuilder<DataRekeySourceAttachmentData>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(DataRekeySourceAttachmentDataChunksInner),
            ]),
            () => ListBuilder<DataRekeySourceAttachmentDataChunksInner>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(DataRekeySourceRecordListDataRecordsInner),
            ]),
            () => ListBuilder<DataRekeySourceRecordListDataRecordsInner>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(PendingSelfRevocationRequest),
            ]),
            () => ListBuilder<PendingSelfRevocationRequest>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(SyncChange)]),
            () => ListBuilder<SyncChange>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(SyncChange)]),
            () => ListBuilder<SyncChange>(),
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
            const FullType(BuiltList, const [
              const FullType(TrustedDeviceSummary),
            ]),
            () => ListBuilder<TrustedDeviceSummary>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(UnsignedAccountSecurityStateEnvelope),
            ]),
            () => ListBuilder<UnsignedAccountSecurityStateEnvelope>(),
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
