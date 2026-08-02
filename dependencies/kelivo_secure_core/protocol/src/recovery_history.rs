use std::collections::HashSet;

use sha2_device::{Digest, Sha256};

use crate::{
    device_crypto::{
        AccountTrustBinding, AccountTrustPublicKey, AccountTrustSignature, DeviceId,
        DeviceKeyAgreementPublicKey, DeviceSigningPublicKey, UserId, verify_account_trust_payload,
    },
    recovery_crypto::{
        RECOVERY_CAPSULE_SHA256_LENGTH, RECOVERY_HISTORY_MAX_BYTES, RecoveryCapsule,
        RecoveryCapsuleExpectation, RecoveryCryptoError, RecoveryGenesisCapability,
        RecoveryHistoryMember, RecoveryHistoryOperation, RecoveryPublicKey,
        VerifiedRecoveryHistoryHead,
    },
};

const MEMBERSHIP_MAGIC: [u8; 8] = *b"KELIVOMM";
const MEMBERSHIP_FORMAT_VERSION: u32 = 2;
const MEMBERSHIP_HEADER_LENGTH: usize = 260;
const MEMBERSHIP_MEMBER_LENGTH: usize = 88;
const MEMBERSHIP_SIGNATURE_LENGTH: usize = 64;
const MEMBERSHIP_SIGNATURE_SECTION_LENGTH: usize = MEMBERSHIP_SIGNATURE_LENGTH * 2;
const MEMBERSHIP_MAX_MEMBERS: usize = 256;
const MEMBERSHIP_MAX_SECURITY_GENERATION: u32 = 0x7fff_ffff;
const MEMBERSHIP_MAX_DEVICE_COUNTER: u32 = 0x7fff_ffff;
const RECOVERY_HISTORY_MAX_ENTRIES: usize = 4096;

const USER_ID_OFFSET: usize = 12;
const SECURITY_GENERATION_OFFSET: usize = 28;
const KEY_EPOCH_OFFSET: usize = 32;
const PREVIOUS_DIGEST_OFFSET: usize = 36;
const TRUST_PUBLIC_KEY_OFFSET: usize = 68;
const RECOVERY_PUBLIC_KEY_VERSION_OFFSET: usize = 100;
const RECOVERY_PUBLIC_KEY_OFFSET: usize = 104;
const RECOVERY_CAPSULE_VERSION_OFFSET: usize = 136;
const RECOVERY_CAPSULE_DIGEST_OFFSET: usize = 140;
const OPERATION_KIND_OFFSET: usize = 172;
const OPERATION_ID_OFFSET: usize = 176;
const ISSUER_DEVICE_ID_OFFSET: usize = 192;
const SUBJECT_DEVICE_ID_OFFSET: usize = 208;
const OPERATION_AUTHORIZATION_DIGEST_OFFSET: usize = 224;
const MEMBER_COUNT_OFFSET: usize = 256;

const MEMBER_KEY_VERSION_OFFSET: usize = 16;
const MEMBER_AUTH_GENERATION_OFFSET: usize = 20;
const MEMBER_SIGNING_PUBLIC_KEY_OFFSET: usize = 24;
const MEMBER_KEY_AGREEMENT_PUBLIC_KEY_OFFSET: usize = 56;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum MembershipOperation {
    Initialize,
    AddDevice,
    RevokeRotate,
    RecoverResume,
    RecoverReplace,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct MembershipMember {
    device_id: DeviceId,
    key_version: u32,
    auth_generation: u32,
    signing_public_key: DeviceSigningPublicKey,
    key_agreement_public_key: DeviceKeyAgreementPublicKey,
}

struct MembershipManifest {
    user_id: UserId,
    security_generation: u32,
    key_epoch: u32,
    previous_digest: [u8; 32],
    current_trust_public_key: AccountTrustPublicKey,
    recovery_public_key_version: u32,
    recovery_public_key: RecoveryPublicKey,
    recovery_capsule_version: u32,
    recovery_capsule_digest: [u8; RECOVERY_CAPSULE_SHA256_LENGTH],
    operation: MembershipOperation,
    operation_id: [u8; 16],
    issuer_device_id: DeviceId,
    subject_device_id: DeviceId,
    operation_authorization_digest: [u8; 32],
    members: Vec<MembershipMember>,
    payload: Vec<u8>,
    transition_signature: [u8; MEMBERSHIP_SIGNATURE_LENGTH],
    current_signature: [u8; MEMBERSHIP_SIGNATURE_LENGTH],
    digest: [u8; 32],
}

#[derive(Clone, Copy)]
struct CapsuleManifestBinding {
    user_id: UserId,
    key_epoch: u32,
    recovery_public_key_version: u32,
    recovery_public_key: RecoveryPublicKey,
    recovery_capsule_version: u32,
    recovery_capsule_digest: [u8; RECOVERY_CAPSULE_SHA256_LENGTH],
}

impl CapsuleManifestBinding {
    fn from_manifest(manifest: &MembershipManifest) -> Self {
        Self {
            user_id: manifest.user_id,
            key_epoch: manifest.key_epoch,
            recovery_public_key_version: manifest.recovery_public_key_version,
            recovery_public_key: manifest.recovery_public_key,
            recovery_capsule_version: manifest.recovery_capsule_version,
            recovery_capsule_digest: manifest.recovery_capsule_digest,
        }
    }
}

pub(crate) struct RecoveryCapsuleExpectations {
    pub current: RecoveryCapsuleExpectation,
    pub source: Option<RecoveryCapsuleExpectation>,
    pub history_head: VerifiedRecoveryHistoryHead,
}

pub(crate) fn verify_history_head(
    expected_recovery_public_key: RecoveryPublicKey,
    expected_user_id: UserId,
    expected_recovery_public_key_version: u32,
    genesis: &RecoveryGenesisCapability,
    history: &[u8],
    source_capsule: Option<&RecoveryCapsule>,
    current_capsule: &RecoveryCapsule,
) -> Result<RecoveryCapsuleExpectations, RecoveryCryptoError> {
    if history.is_empty() || history.len() > RECOVERY_HISTORY_MAX_BYTES {
        return Err(RecoveryCryptoError::InvalidMembershipHistory);
    }
    let mut offset = 0;
    let first_length = manifest_length_at(history, offset)?;
    let first_bytes = &history[..first_length];
    if !same_bytes(first_bytes, genesis.as_bytes()) {
        return Err(RecoveryCryptoError::MembershipHistoryAnchorMismatch);
    }
    let mut current = parse_manifest(first_bytes)?;
    validate_genesis(
        &current,
        expected_user_id,
        expected_recovery_public_key_version,
        expected_recovery_public_key,
    )?;
    let mut operation_ids = HashSet::with_capacity(RECOVERY_HISTORY_MAX_ENTRIES.min(64));
    operation_ids.insert(current.operation_id);
    let mut operations = vec![recovery_history_operation(&current)];
    offset = first_length;
    let mut entry_count = 1;
    let mut latest_rotation_source = None;
    while offset < history.len() {
        if entry_count == RECOVERY_HISTORY_MAX_ENTRIES {
            return Err(RecoveryCryptoError::InvalidMembershipHistory);
        }
        let length = manifest_length_at(history, offset)?;
        let next_offset = offset
            .checked_add(length)
            .ok_or(RecoveryCryptoError::InvalidMembershipHistory)?;
        let next = parse_manifest(&history[offset..next_offset])?;
        if !operation_ids.insert(next.operation_id) {
            return Err(RecoveryCryptoError::MembershipHistoryTransitionInvalid);
        }
        validate_successor(&current, &next)?;
        operations.push(recovery_history_operation(&next));
        if matches!(
            next.operation,
            MembershipOperation::RevokeRotate | MembershipOperation::RecoverReplace
        ) {
            latest_rotation_source = Some(CapsuleManifestBinding::from_manifest(&current));
        }
        current = next;
        offset = next_offset;
        entry_count += 1;
    }

    let capsule_digest: [u8; RECOVERY_CAPSULE_SHA256_LENGTH] =
        Sha256::digest(current_capsule.as_bytes()).into();
    if current_capsule.user_id()? != current.user_id
        || current_capsule.key_epoch() != current.key_epoch
        || current_capsule.recovery_public_key_version() != current.recovery_public_key_version
        || current_capsule.capsule_version() != current.recovery_capsule_version
        || current_capsule.recovery_public_key()? != current.recovery_public_key
        || current.recovery_public_key != expected_recovery_public_key
        || !same_bytes(&capsule_digest, &current.recovery_capsule_digest)
    {
        return Err(RecoveryCryptoError::MembershipHistoryHeadMismatch);
    }

    let current_expectation = RecoveryCapsuleExpectation::new(
        current.user_id,
        current.key_epoch,
        current.recovery_public_key_version,
        current.recovery_capsule_version,
        capsule_digest,
    )?;
    let source_expectation = if current.key_epoch == 1 {
        if source_capsule.is_some() {
            return Err(RecoveryCryptoError::MembershipHistoryHeadMismatch);
        }
        None
    } else {
        let source_binding =
            latest_rotation_source.ok_or(RecoveryCryptoError::MembershipHistoryHeadMismatch)?;
        if source_binding.key_epoch.checked_add(1) != Some(current.key_epoch) {
            return Err(RecoveryCryptoError::MembershipHistoryHeadMismatch);
        }
        let source_capsule =
            source_capsule.ok_or(RecoveryCryptoError::MembershipHistoryHeadMismatch)?;
        let source_digest: [u8; RECOVERY_CAPSULE_SHA256_LENGTH] =
            Sha256::digest(source_capsule.as_bytes()).into();
        if source_capsule.user_id()? != source_binding.user_id
            || source_capsule.key_epoch() != source_binding.key_epoch
            || source_capsule.recovery_public_key_version()
                != source_binding.recovery_public_key_version
            || source_capsule.capsule_version() != source_binding.recovery_capsule_version
            || source_capsule.recovery_public_key()? != source_binding.recovery_public_key
            || !same_bytes(&source_digest, &source_binding.recovery_capsule_digest)
        {
            return Err(RecoveryCryptoError::MembershipHistoryHeadMismatch);
        }
        Some(RecoveryCapsuleExpectation::new(
            source_binding.user_id,
            source_binding.key_epoch,
            source_binding.recovery_public_key_version,
            source_binding.recovery_capsule_version,
            source_digest,
        )?)
    };
    let history_head = VerifiedRecoveryHistoryHead {
        user_id: current.user_id,
        security_generation: current.security_generation,
        key_epoch: current.key_epoch,
        digest: current.digest,
        current_trust_public_key: current.current_trust_public_key,
        recovery_public_key_version: current.recovery_public_key_version,
        recovery_public_key: current.recovery_public_key,
        recovery_capsule_version: current.recovery_capsule_version,
        recovery_capsule_digest: current.recovery_capsule_digest,
        operation_kind: match current.operation {
            MembershipOperation::Initialize => 1,
            MembershipOperation::AddDevice => 2,
            MembershipOperation::RevokeRotate => 3,
            MembershipOperation::RecoverResume => 4,
            MembershipOperation::RecoverReplace => 5,
        },
        operation_id: current.operation_id,
        issuer_device_id: current.issuer_device_id,
        subject_device_id: current.subject_device_id,
        operation_authorization_digest: current.operation_authorization_digest,
        members: current
            .members
            .iter()
            .map(|member| RecoveryHistoryMember {
                device_id: member.device_id,
                key_version: member.key_version,
                auth_generation: member.auth_generation,
                signing_public_key: member.signing_public_key,
                key_agreement_public_key: member.key_agreement_public_key,
            })
            .collect(),
        operations,
        manifest: current
            .payload
            .iter()
            .copied()
            .chain(
                current
                    .transition_signature
                    .iter()
                    .chain(current.current_signature.iter())
                    .copied(),
            )
            .collect(),
    };
    Ok(RecoveryCapsuleExpectations {
        current: current_expectation,
        source: source_expectation,
        history_head,
    })
}

fn recovery_history_operation(manifest: &MembershipManifest) -> RecoveryHistoryOperation {
    RecoveryHistoryOperation {
        kind: match manifest.operation {
            MembershipOperation::Initialize => 1,
            MembershipOperation::AddDevice => 2,
            MembershipOperation::RevokeRotate => 3,
            MembershipOperation::RecoverResume => 4,
            MembershipOperation::RecoverReplace => 5,
        },
        operation_id: manifest.operation_id,
        key_epoch: manifest.key_epoch,
        authorization_digest: manifest.operation_authorization_digest,
    }
}

fn manifest_length_at(history: &[u8], offset: usize) -> Result<usize, RecoveryCryptoError> {
    let remaining = history
        .get(offset..)
        .ok_or(RecoveryCryptoError::InvalidMembershipHistory)?;
    if remaining.len() < MEMBERSHIP_HEADER_LENGTH {
        return Err(RecoveryCryptoError::InvalidMembershipHistory);
    }
    let member_count = read_u32(remaining, MEMBER_COUNT_OFFSET) as usize;
    if !(1..=MEMBERSHIP_MAX_MEMBERS).contains(&member_count) {
        return Err(RecoveryCryptoError::InvalidMembershipHistory);
    }
    let member_bytes = member_count
        .checked_mul(MEMBERSHIP_MEMBER_LENGTH)
        .ok_or(RecoveryCryptoError::InvalidMembershipHistory)?;
    let length = MEMBERSHIP_HEADER_LENGTH
        .checked_add(member_bytes)
        .and_then(|value| value.checked_add(MEMBERSHIP_SIGNATURE_SECTION_LENGTH))
        .ok_or(RecoveryCryptoError::InvalidMembershipHistory)?;
    if remaining.len() < length {
        return Err(RecoveryCryptoError::InvalidMembershipHistory);
    }
    Ok(length)
}

fn parse_manifest(bytes: &[u8]) -> Result<MembershipManifest, RecoveryCryptoError> {
    if bytes.len() < MEMBERSHIP_HEADER_LENGTH + MEMBERSHIP_SIGNATURE_SECTION_LENGTH
        || bytes[..8] != MEMBERSHIP_MAGIC
        || read_u32(bytes, 8) != MEMBERSHIP_FORMAT_VERSION
    {
        return Err(RecoveryCryptoError::InvalidMembershipHistory);
    }
    let member_count = read_u32(bytes, MEMBER_COUNT_OFFSET) as usize;
    if !(1..=MEMBERSHIP_MAX_MEMBERS).contains(&member_count) {
        return Err(RecoveryCryptoError::InvalidMembershipHistory);
    }
    let payload_length = MEMBERSHIP_HEADER_LENGTH
        .checked_add(
            member_count
                .checked_mul(MEMBERSHIP_MEMBER_LENGTH)
                .ok_or(RecoveryCryptoError::InvalidMembershipHistory)?,
        )
        .ok_or(RecoveryCryptoError::InvalidMembershipHistory)?;
    if bytes.len() != payload_length + MEMBERSHIP_SIGNATURE_SECTION_LENGTH {
        return Err(RecoveryCryptoError::InvalidMembershipHistory);
    }

    let security_generation = read_u32(bytes, SECURITY_GENERATION_OFFSET);
    let key_epoch = read_u32(bytes, KEY_EPOCH_OFFSET);
    let recovery_public_key_version = read_u32(bytes, RECOVERY_PUBLIC_KEY_VERSION_OFFSET);
    let recovery_capsule_version = read_u32(bytes, RECOVERY_CAPSULE_VERSION_OFFSET);
    if security_generation == 0
        || security_generation > MEMBERSHIP_MAX_SECURITY_GENERATION
        || key_epoch == 0
        || recovery_public_key_version == 0
        || recovery_capsule_version == 0
    {
        return Err(RecoveryCryptoError::InvalidMembershipHistory);
    }
    let operation = match read_u32(bytes, OPERATION_KIND_OFFSET) {
        1 => MembershipOperation::Initialize,
        2 => MembershipOperation::AddDevice,
        3 => MembershipOperation::RevokeRotate,
        4 => MembershipOperation::RecoverResume,
        5 => MembershipOperation::RecoverReplace,
        _ => return Err(RecoveryCryptoError::InvalidMembershipHistory),
    };
    let user_id = UserId::new(copy_array(
        &bytes[USER_ID_OFFSET..SECURITY_GENERATION_OFFSET],
    ))
    .map_err(|_| RecoveryCryptoError::InvalidMembershipHistory)?;
    let operation_id = copy_array(&bytes[OPERATION_ID_OFFSET..ISSUER_DEVICE_ID_OFFSET]);
    DeviceId::new(operation_id).map_err(|_| RecoveryCryptoError::InvalidMembershipHistory)?;
    let issuer_device_id = DeviceId::new(copy_array(
        &bytes[ISSUER_DEVICE_ID_OFFSET..SUBJECT_DEVICE_ID_OFFSET],
    ))
    .map_err(|_| RecoveryCryptoError::InvalidMembershipHistory)?;
    let subject_device_id = DeviceId::new(copy_array(
        &bytes[SUBJECT_DEVICE_ID_OFFSET..OPERATION_AUTHORIZATION_DIGEST_OFFSET],
    ))
    .map_err(|_| RecoveryCryptoError::InvalidMembershipHistory)?;
    let current_trust_public_key = AccountTrustPublicKey::from_bytes(copy_array(
        &bytes[TRUST_PUBLIC_KEY_OFFSET..RECOVERY_PUBLIC_KEY_VERSION_OFFSET],
    ))
    .map_err(|_| RecoveryCryptoError::InvalidMembershipHistory)?;
    let recovery_public_key = RecoveryPublicKey::from_bytes(copy_array(
        &bytes[RECOVERY_PUBLIC_KEY_OFFSET..RECOVERY_CAPSULE_VERSION_OFFSET],
    ))?;

    let mut members: Vec<MembershipMember> = Vec::with_capacity(member_count);
    for index in 0..member_count {
        let member_offset = MEMBERSHIP_HEADER_LENGTH + index * MEMBERSHIP_MEMBER_LENGTH;
        let key_version = read_u32(bytes, member_offset + MEMBER_KEY_VERSION_OFFSET);
        let auth_generation = read_u32(bytes, member_offset + MEMBER_AUTH_GENERATION_OFFSET);
        if key_version == 0
            || key_version > MEMBERSHIP_MAX_DEVICE_COUNTER
            || auth_generation > MEMBERSHIP_MAX_DEVICE_COUNTER
        {
            return Err(RecoveryCryptoError::InvalidMembershipHistory);
        }
        let member = MembershipMember {
            device_id: DeviceId::new(copy_array(&bytes[member_offset..member_offset + 16]))
                .map_err(|_| RecoveryCryptoError::InvalidMembershipHistory)?,
            key_version,
            auth_generation,
            signing_public_key: DeviceSigningPublicKey::from_bytes(copy_array(
                &bytes[member_offset + MEMBER_SIGNING_PUBLIC_KEY_OFFSET
                    ..member_offset + MEMBER_KEY_AGREEMENT_PUBLIC_KEY_OFFSET],
            ))
            .map_err(|_| RecoveryCryptoError::InvalidMembershipHistory)?,
            key_agreement_public_key: DeviceKeyAgreementPublicKey::from_bytes(copy_array(
                &bytes[member_offset + MEMBER_KEY_AGREEMENT_PUBLIC_KEY_OFFSET
                    ..member_offset + MEMBERSHIP_MEMBER_LENGTH],
            ))
            .map_err(|_| RecoveryCryptoError::InvalidMembershipHistory)?,
        };
        if let Some(previous) = members.last()
            && previous.device_id.as_bytes() >= member.device_id.as_bytes()
        {
            return Err(RecoveryCryptoError::InvalidMembershipHistory);
        }
        if members.iter().any(|existing| {
            existing.signing_public_key == member.signing_public_key
                || existing.key_agreement_public_key == member.key_agreement_public_key
        }) {
            return Err(RecoveryCryptoError::InvalidMembershipHistory);
        }
        if member.key_agreement_public_key.as_bytes() == recovery_public_key.as_bytes() {
            return Err(RecoveryCryptoError::InvalidMembershipHistory);
        }
        members.push(member);
    }

    Ok(MembershipManifest {
        user_id,
        security_generation,
        key_epoch,
        previous_digest: copy_array(&bytes[PREVIOUS_DIGEST_OFFSET..TRUST_PUBLIC_KEY_OFFSET]),
        current_trust_public_key,
        recovery_public_key_version,
        recovery_public_key,
        recovery_capsule_version,
        recovery_capsule_digest: copy_array(
            &bytes[RECOVERY_CAPSULE_DIGEST_OFFSET..OPERATION_KIND_OFFSET],
        ),
        operation,
        operation_id,
        issuer_device_id,
        subject_device_id,
        operation_authorization_digest: copy_array(
            &bytes[OPERATION_AUTHORIZATION_DIGEST_OFFSET..MEMBER_COUNT_OFFSET],
        ),
        members,
        payload: bytes[..payload_length].to_vec(),
        transition_signature: copy_array(
            &bytes[payload_length..payload_length + MEMBERSHIP_SIGNATURE_LENGTH],
        ),
        current_signature: copy_array(&bytes[payload_length + MEMBERSHIP_SIGNATURE_LENGTH..]),
        digest: Sha256::digest(bytes).into(),
    })
}

fn validate_genesis(
    genesis: &MembershipManifest,
    expected_user_id: UserId,
    expected_recovery_public_key_version: u32,
    expected_recovery_public_key: RecoveryPublicKey,
) -> Result<(), RecoveryCryptoError> {
    if genesis.user_id != expected_user_id
        || genesis.security_generation != 1
        || genesis.key_epoch != 1
        || genesis.previous_digest.iter().any(|byte| *byte != 0)
        || genesis.recovery_public_key_version != 1
        || genesis.recovery_public_key_version != expected_recovery_public_key_version
        || genesis.recovery_public_key != expected_recovery_public_key
        || genesis.recovery_capsule_version != 1
        || genesis.operation != MembershipOperation::Initialize
        || genesis.issuer_device_id != genesis.subject_device_id
        || genesis.members.len() != 1
        || genesis.members[0].device_id != genesis.subject_device_id
        || genesis.members[0].auth_generation != 0
        || genesis
            .operation_authorization_digest
            .iter()
            .any(|byte| *byte != 0)
        || genesis.transition_signature.iter().any(|byte| *byte != 0)
    {
        return Err(RecoveryCryptoError::MembershipHistoryAnchorMismatch);
    }
    verify_current_signature(genesis)
}

fn validate_successor(
    previous: &MembershipManifest,
    current: &MembershipManifest,
) -> Result<(), RecoveryCryptoError> {
    if previous.security_generation == MEMBERSHIP_MAX_SECURITY_GENERATION
        || current.user_id != previous.user_id
        || current.security_generation != previous.security_generation + 1
        || !same_bytes(&current.previous_digest, &previous.digest)
        || current.operation == MembershipOperation::Initialize
    {
        return Err(RecoveryCryptoError::MembershipHistoryTransitionInvalid);
    }

    match current.operation {
        MembershipOperation::Initialize => unreachable!("初始化已在前置条件拒绝"),
        MembershipOperation::AddDevice => validate_add_device(previous, current)?,
        MembershipOperation::RevokeRotate => validate_revoke_rotate(previous, current)?,
        MembershipOperation::RecoverResume => validate_recover_resume(previous, current)?,
        MembershipOperation::RecoverReplace => validate_recover_replace(previous, current)?,
    }
    verify_current_signature(current)
}

fn validate_add_device(
    previous: &MembershipManifest,
    current: &MembershipManifest,
) -> Result<(), RecoveryCryptoError> {
    let expected_member_count = previous
        .members
        .len()
        .checked_add(1)
        .ok_or(RecoveryCryptoError::MembershipHistoryTransitionInvalid)?;
    let subject = find_member(current, current.subject_device_id);
    if current.key_epoch != previous.key_epoch
        || current.current_trust_public_key != previous.current_trust_public_key
        || !same_recovery_state(previous, current)
        || current.issuer_device_id == current.subject_device_id
        || find_member(previous, current.issuer_device_id).is_none()
        || find_member(previous, current.subject_device_id).is_some()
        || current.members.len() != expected_member_count
        || subject.is_none_or(|member| member.auth_generation == 0)
        || current
            .operation_authorization_digest
            .iter()
            .any(|byte| *byte != 0)
        || current.transition_signature.iter().any(|byte| *byte != 0)
        || !unchanged_members(previous, current, None)
    {
        return Err(RecoveryCryptoError::MembershipHistoryTransitionInvalid);
    }
    Ok(())
}

fn validate_revoke_rotate(
    previous: &MembershipManifest,
    current: &MembershipManifest,
) -> Result<(), RecoveryCryptoError> {
    let expected_member_count = previous
        .members
        .len()
        .checked_sub(1)
        .ok_or(RecoveryCryptoError::MembershipHistoryTransitionInvalid)?;
    if previous.key_epoch == u32::MAX
        || current.key_epoch != previous.key_epoch + 1
        || current.current_trust_public_key == previous.current_trust_public_key
        || current.issuer_device_id == current.subject_device_id
        || find_member(previous, current.issuer_device_id).is_none()
        || find_member(previous, current.subject_device_id).is_none()
        || find_member(current, current.issuer_device_id).is_none()
        || find_member(current, current.subject_device_id).is_some()
        || current.members.len() != expected_member_count
        || current.recovery_public_key_version != previous.recovery_public_key_version
        || current.recovery_public_key != previous.recovery_public_key
        || previous.recovery_capsule_version == u32::MAX
        || current.recovery_capsule_version != previous.recovery_capsule_version + 1
        || same_bytes(
            &current.recovery_capsule_digest,
            &previous.recovery_capsule_digest,
        )
        || current.transition_signature.iter().all(|byte| *byte == 0)
        || !unchanged_members(previous, current, Some(current.subject_device_id))
    {
        return Err(RecoveryCryptoError::MembershipHistoryTransitionInvalid);
    }
    verify_signature(
        &previous.current_trust_public_key,
        AccountTrustBinding {
            user_id: current.user_id,
            key_epoch: previous.key_epoch,
        },
        &current.payload,
        &current.transition_signature,
    )
}

fn validate_recover_resume(
    previous: &MembershipManifest,
    current: &MembershipManifest,
) -> Result<(), RecoveryCryptoError> {
    let expected_member_count = previous
        .members
        .len()
        .checked_add(1)
        .ok_or(RecoveryCryptoError::MembershipHistoryTransitionInvalid)?;
    let subject = find_member(current, current.subject_device_id);
    if current.key_epoch != previous.key_epoch
        || current.current_trust_public_key != previous.current_trust_public_key
        || !same_recovery_state(previous, current)
        || current.issuer_device_id != current.subject_device_id
        || find_member(previous, current.subject_device_id).is_some()
        || current.members.len() != expected_member_count
        || subject.is_none_or(|member| member.auth_generation == 0)
        || current
            .operation_authorization_digest
            .iter()
            .any(|byte| *byte != 0)
        || current.transition_signature.iter().any(|byte| *byte != 0)
        || !unchanged_members(previous, current, None)
    {
        return Err(RecoveryCryptoError::MembershipHistoryTransitionInvalid);
    }
    Ok(())
}

fn validate_recover_replace(
    previous: &MembershipManifest,
    current: &MembershipManifest,
) -> Result<(), RecoveryCryptoError> {
    let subject = find_member(current, current.subject_device_id);
    let subject_matches_resume = previous.operation == MembershipOperation::RecoverResume
        && find_member(previous, previous.subject_device_id) == subject
        && previous.subject_device_id == current.subject_device_id;
    let subject_is_direct_replacement = previous.operation != MembershipOperation::RecoverResume
        && subject.is_some_and(|member| {
            find_member(previous, current.subject_device_id).is_none()
                && previous.members.iter().all(|old_member| {
                    old_member.signing_public_key != member.signing_public_key
                        && old_member.key_agreement_public_key != member.key_agreement_public_key
                })
        });
    if previous.key_epoch == u32::MAX
        || current.key_epoch != previous.key_epoch + 1
        || current.current_trust_public_key == previous.current_trust_public_key
        || current.issuer_device_id != current.subject_device_id
        || current.members.len() != 1
        || subject.is_none_or(|member| member.auth_generation == 0)
        || !(subject_matches_resume || subject_is_direct_replacement)
        || current
            .operation_authorization_digest
            .iter()
            .any(|byte| *byte != 0)
        || current.recovery_public_key_version != previous.recovery_public_key_version
        || current.recovery_public_key != previous.recovery_public_key
        || previous.recovery_capsule_version == u32::MAX
        || current.recovery_capsule_version != previous.recovery_capsule_version + 1
        || same_bytes(
            &current.recovery_capsule_digest,
            &previous.recovery_capsule_digest,
        )
        || current.transition_signature.iter().all(|byte| *byte == 0)
    {
        return Err(RecoveryCryptoError::MembershipHistoryTransitionInvalid);
    }
    verify_signature(
        &previous.current_trust_public_key,
        AccountTrustBinding {
            user_id: current.user_id,
            key_epoch: previous.key_epoch,
        },
        &current.payload,
        &current.transition_signature,
    )
}

fn verify_current_signature(manifest: &MembershipManifest) -> Result<(), RecoveryCryptoError> {
    verify_signature(
        &manifest.current_trust_public_key,
        AccountTrustBinding {
            user_id: manifest.user_id,
            key_epoch: manifest.key_epoch,
        },
        &manifest.payload,
        &manifest.current_signature,
    )
}

fn verify_signature(
    public_key: &AccountTrustPublicKey,
    binding: AccountTrustBinding,
    payload: &[u8],
    signature: &[u8; MEMBERSHIP_SIGNATURE_LENGTH],
) -> Result<(), RecoveryCryptoError> {
    let signature = AccountTrustSignature::from_bytes(signature)
        .map_err(|_| RecoveryCryptoError::MembershipHistorySignatureInvalid)?;
    verify_account_trust_payload(public_key, binding, payload, &signature)
        .map_err(|_| RecoveryCryptoError::MembershipHistorySignatureInvalid)
}

fn find_member(manifest: &MembershipManifest, device_id: DeviceId) -> Option<&MembershipMember> {
    manifest
        .members
        .iter()
        .find(|member| member.device_id == device_id)
}

fn unchanged_members(
    previous: &MembershipManifest,
    current: &MembershipManifest,
    omitted_device_id: Option<DeviceId>,
) -> bool {
    previous.members.iter().all(|old_member| {
        if Some(old_member.device_id) == omitted_device_id {
            true
        } else {
            find_member(current, old_member.device_id) == Some(old_member)
        }
    })
}

fn same_recovery_state(left: &MembershipManifest, right: &MembershipManifest) -> bool {
    left.recovery_public_key_version == right.recovery_public_key_version
        && left.recovery_public_key == right.recovery_public_key
        && left.recovery_capsule_version == right.recovery_capsule_version
        && same_bytes(
            &left.recovery_capsule_digest,
            &right.recovery_capsule_digest,
        )
}

fn read_u32(bytes: &[u8], offset: usize) -> u32 {
    u32::from_be_bytes(copy_array(&bytes[offset..offset + 4]))
}

fn same_bytes(left: &[u8], right: &[u8]) -> bool {
    left.len() == right.len()
        && left
            .iter()
            .zip(right)
            .fold(0_u8, |difference, (left, right)| {
                difference | (left ^ right)
            })
            == 0
}

fn copy_array<const LENGTH: usize>(bytes: &[u8]) -> [u8; LENGTH] {
    let mut output = [0_u8; LENGTH];
    output.copy_from_slice(bytes);
    output
}

#[cfg(test)]
mod tests {
    use base64ct::{Base64Url, Encoding};

    use super::*;

    const DART_INIT: &str = "S0VMSVZPTU0AAAACcAAAAAAAQACAAAAAAAAAAQAAAAEAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADGukVpqxpKKb7327NSIZoQDnypuTvOcwZRu6WPOJ7N9AAAAAHdcNizmGV7lSarTk0dOJ3AcGcuNv_hdOgcSyttHlb1YQAAAAHZsfPixtUoZopz8iV1xE7Z-Y2caElkdhtiFBfv2A16YAAAAAFQAAAAAABAAIAAAAAAAAABgAAAAAAAQACAAAAAAAAAAYAAAAAAAEAAgAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAAAAAAABAAIAAAAAAAAABAAAAAQAAAABkCWCQOAtJwkHe2y6WyXI2zvEKUkuD0VIaOlQNR-P5sNO8ZAdbShbiNX4vOAUtEjBjPRRAAdoofmUKAhY9FngVAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABRchNtfNvxE9RFzJGH3Dy8lFu437rKxS8XQYcWPoBGwP8dWlf80C2rKqN4xiL-cqN7s-twIEpPX1zb7GD0ulw8=";
    const DART_INIT_DIGEST: &str = "05HPAtPXROeSH0q-hR9L3XRc1aQPMF8n05DghrDFUi8=";
    const DART_ADD: &str = "S0VMSVZPTU0AAAACcAAAAAAAQACAAAAAAAAAAQAAAAIAAAAB05HPAtPXROeSH0q-hR9L3XRc1aQPMF8n05DghrDFUi_GukVpqxpKKb7327NSIZoQDnypuTvOcwZRu6WPOJ7N9AAAAAHdcNizmGV7lSarTk0dOJ3AcGcuNv_hdOgcSyttHlb1YQAAAAHZsfPixtUoZopz8iV1xE7Z-Y2caElkdhtiFBfv2A16YAAAAAKQAAAAAABAAIAAAAAAAAECgAAAAAAAQACAAAAAAAAAAZAAAAAAAEAAgAAAAAAAAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAAAAABAAIAAAAAAAAABAAAAAQAAAABkCWCQOAtJwkHe2y6WyXI2zvEKUkuD0VIaOlQNR-P5sNO8ZAdbShbiNX4vOAUtEjBjPRRAAdoofmUKAhY9FngVkAAAAAAAQACAAAAAAAABAQAAAAEAAAABJN6Lhjzf3JAmNndeTSZas-gkRy_PHT13A3F21JfYcNVx_bKKmvgFLu2jtfVT3SDGmmtPr7kPaIRNDlpgaJPONAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA8Jp5SY8OMWGQlUuX8P9uByzKZkfZ_BAABAgIMEDbGkcdpkkL8jKHrxWfXXMudiusorxqxnFcq6U1RutmjiskC";
    const DART_ADD_DIGEST: &str = "YK_d1CAY4CnUQukssxT6jZCY6sSDyZ3cq3TZTszE0iE=";
    const DART_REVOKE: &str = "S0VMSVZPTU0AAAACcAAAAAAAQACAAAAAAAAAAQAAAAMAAAACYK_d1CAY4CnUQukssxT6jZCY6sSDyZ3cq3TZTszE0iFBKYAXQdhCsoXJ8NK_2xAp7hO3Mi2BBjbO49mscH2EeAAAAAHdcNizmGV7lSarTk0dOJ3AcGcuNv_hdOgcSyttHlb1YQAAAAKMvCPqXupQkBoOv3kpgEJqpju6Xq637q5HKomKPuN09wAAAAOQAAAAAABAAIAAAAAAAAEFgAAAAAAAQACAAAAAAAAAAZAAAAAAAEAAgAAAAAAAAQFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUQAAAAGAAAAAAABAAIAAAAAAAAABAAAAAQAAAABkCWCQOAtJwkHe2y6WyXI2zvEKUkuD0VIaOlQNR-P5sNO8ZAdbShbiNX4vOAUtEjBjPRRAAdoofmUKAhY9FngV6P5mgbJusLnAH-4iYHZSzcQe6fAYc27aYm3gdQyOXW-MZsfXqL_HQUOPsKEDlj9n8Sh-LOeGddlc2ay7O0ZPDFM00n9-1kLDBZlw-zHyUowk3dARCRnOU8K_klM_Yun_pvWdp3F8RVinPhTH78kF8P2g3psJGoQ72_k5O-xjkQc=";
    const DART_REVOKE_DIGEST: &str = "G7pb1XYcWVtnnG1lZzHl5UivRPBpekjvxp6qUamvEqo=";
    const DART_RESUME: &str = "S0VMSVZPTU0AAAACcAAAAAAAQACAAAAAAAAAAQAAAAQAAAACG7pb1XYcWVtnnG1lZzHl5UivRPBpekjvxp6qUamvEqpBKYAXQdhCsoXJ8NK_2xAp7hO3Mi2BBjbO49mscH2EeAAAAAHdcNizmGV7lSarTk0dOJ3AcGcuNv_hdOgcSyttHlb1YQAAAAKMvCPqXupQkBoOv3kpgEJqpju6Xq637q5HKomKPuN09wAAAASQAAAAAABAAIAAAAAAAAEHkAAAAAAAQACAAAAAAAABBpAAAAAAAEAAgAAAAAAAAQYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAAAAABAAIAAAAAAAAABAAAAAQAAAABkCWCQOAtJwkHe2y6WyXI2zvEKUkuD0VIaOlQNR-P5sNO8ZAdbShbiNX4vOAUtEjBjPRRAAdoofmUKAhY9FngVkAAAAAAAQACAAAAAAAABBgAAAAEAAAABgdIlodNdqTKZrV-1klAXdgXZkX--B30hzXsjLBMkKk3Gd8znvWfqfRtKVxTbElc6PyPTRh1foRX3Y6VY1-kwewAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAywzUx0Vy0qXRMsNYCBwMvpfduygnmZfR1iAkPMTsIb411KqH0Ru3YB-l8QbUc1WZQyMIyPI5kDIPimcijKCEL";
    const DART_RESUME_DIGEST: &str = "KUa5iTtfhjRhHm6HgnOqLdKrcMUeq2D9Y90RygxrnKo=";
    const DART_REPLACE: &str = "S0VMSVZPTU0AAAACcAAAAAAAQACAAAAAAAAAAQAAAAUAAAADKUa5iTtfhjRhHm6HgnOqLdKrcMUeq2D9Y90RygxrnKqiI_8VH8y31X2yfFQY-X5kcA9Rn_BnnARxRCt-qLc9MAAAAAHdcNizmGV7lSarTk0dOJ3AcGcuNv_hdOgcSyttHlb1YQAAAAMj5alo_Jncfvde8oXxu6mtnu0hJJ-hJJVGKZMV_7x4iQAAAAWQAAAAAABAAIAAAAAAAAEIkAAAAAAAQACAAAAAAAABBpAAAAAAAEAAgAAAAAAAAQYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGQAAAAAABAAIAAAAAAAAEGAAAAAQAAAAGB0iWh012pMpmtX7WSUBd2BdmRf74HfSHNeyMsEyQqTcZ3zOe9Z-p9G0pXFNsSVzo_I9NGHV-hFfdjpVjX6TB7T6V_HIXj7StNhx5Ry0MvFZzvHdtsw5wKWp-vUl2q2aSCe9hG1AZ9ex_vHEjKhnNDgSb9YEDUdgzAwV6u3W9lAoWRoPC9qV8tBZ47iKrMKN2MwLWSoFE9h4oTfa-zpZrOrqpq5CjsjXW4k_cT7zl40-J66eRal6O_lt4TvKd61wQ=";
    const DART_REPLACE_DIGEST: &str = "UTGRh5hTkjhzE9CnK0w8AhTQ2hwbbmPuDN919DL48-4=";

    #[test]
    fn dart_recovery_operations_match_rust_wire_and_signatures() {
        let init = parse_dart_manifest(DART_INIT, DART_INIT_DIGEST);
        let add = parse_dart_manifest(DART_ADD, DART_ADD_DIGEST);
        let revoke = parse_dart_manifest(DART_REVOKE, DART_REVOKE_DIGEST);
        let resume = parse_dart_manifest(DART_RESUME, DART_RESUME_DIGEST);
        let replace = parse_dart_manifest(DART_REPLACE, DART_REPLACE_DIGEST);

        validate_genesis(
            &init,
            init.user_id,
            init.recovery_public_key_version,
            init.recovery_public_key,
        )
        .expect("Dart 初始化清单应通过 Rust 验证");
        validate_successor(&init, &add).expect("Dart 新增设备应通过 Rust 验证");
        validate_successor(&add, &revoke).expect("Dart 撤销轮换应通过 Rust 验证");
        validate_successor(&revoke, &resume).expect("Dart 恢复接续应通过 Rust 验证");
        validate_successor(&resume, &replace).expect("Dart 恢复替换应通过 Rust 验证");
        for manifest in [&init, &add, &resume, &replace] {
            assert!(
                manifest
                    .operation_authorization_digest
                    .iter()
                    .all(|byte| *byte == 0)
            );
        }
        assert_eq!(revoke.operation_authorization_digest, [0x51; 32]);
        assert_eq!(add.operation, MembershipOperation::AddDevice);
        assert_eq!(revoke.operation, MembershipOperation::RevokeRotate);
        assert_eq!(resume.operation, MembershipOperation::RecoverResume);
        assert_eq!(replace.operation, MembershipOperation::RecoverReplace);
        assert_eq!(
            [
                init.security_generation,
                add.security_generation,
                revoke.security_generation,
                resume.security_generation,
                replace.security_generation,
            ],
            [1, 2, 3, 4, 5]
        );
        assert_eq!(
            [
                init.key_epoch,
                add.key_epoch,
                revoke.key_epoch,
                resume.key_epoch,
                replace.key_epoch,
            ],
            [1, 1, 2, 2, 3]
        );
        assert!(init.transition_signature.iter().all(|byte| *byte == 0));
        assert!(add.transition_signature.iter().all(|byte| *byte == 0));
        assert!(revoke.transition_signature.iter().any(|byte| *byte != 0));
        assert!(resume.transition_signature.iter().all(|byte| *byte == 0));
        assert!(replace.transition_signature.iter().any(|byte| *byte != 0));

        let mut legacy_init = Base64Url::decode_vec(DART_INIT).expect("Dart 清单应可解码");
        legacy_init[8..12].copy_from_slice(&1_u32.to_be_bytes());
        assert!(matches!(
            parse_manifest(&legacy_init),
            Err(RecoveryCryptoError::InvalidMembershipHistory)
        ));
    }

    fn parse_dart_manifest(encoded: &str, encoded_digest: &str) -> MembershipManifest {
        let bytes = Base64Url::decode_vec(encoded).expect("Dart 清单固定向量应是规范 base64url");
        let expected_digest =
            Base64Url::decode_vec(encoded_digest).expect("Dart 摘要固定向量应是规范 base64url");
        let manifest = parse_manifest(&bytes).expect("Dart 清单固定向量应由 Rust 解析");
        assert_eq!(manifest.digest.as_slice(), expected_digest);
        manifest
    }
}
