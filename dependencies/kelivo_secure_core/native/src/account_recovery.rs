use std::{
    collections::{HashMap, hash_map::Entry},
    sync::{Arc, Mutex, OnceLock},
};

use hkdf::Hkdf;
use hmac::{Hmac, KeyInit as HmacKeyInit, Mac};
use kelivo_secure_core_protocol::{
    account_recovery as protocol,
    device_crypto::{self as crypto, AccountTrustBinding},
    recovery_crypto as recovery,
};
use sha2::{Digest, Sha256};
use subtle::ConstantTimeEq;
use zeroize::Zeroizing;

use crate::{
    HANDLE_RESERVED_MASK, HANDLE_TAG_MASK, KelivoStatus, key_for_handle, master_key, read_input,
    write_bytes, write_output,
};

const UUID_LENGTH: usize = 16;
const SHA256_LENGTH: usize = 32;
const TRUST_SIGNATURE_LENGTH: usize = 64;
const RECOVERY_EXECUTION_SUBTYPE: u64 = 1_u64 << 59;
const RECOVERY_EXECUTION_HANDLE_TAG: u64 = crate::RECOVERY_HANDLE_TAG | RECOVERY_EXECUTION_SUBTYPE;
const RECOVERY_EXECUTION_SEQUENCE_MASK: u64 = RECOVERY_EXECUTION_SUBTYPE - 1;
const MAX_ACTIVE_RECOVERY_EXECUTIONS: usize = 64;
const PROOF_BINDING_STRUCT_SIZE: u32 = 120;
const REPLACEMENT_PROOF_BINDING_STRUCT_SIZE: u32 = 232;
const PREPARE_INPUT_STRUCT_SIZE: u32 = 92;
const PREPARE_BINDING_STRUCT_SIZE: u32 = 96;
const STATE_BINDING_STRUCT_SIZE: u32 = 152;
const PREPARE_KIND_RESUME: u32 = 1;
const PREPARE_KIND_REPLACEMENT: u32 = 2;
const PREPARE_MANIFEST_MAX_LENGTH: usize = 260 + 256 * 88 + 128;
const ACCOUNT_RECOVERY_CONTINUATION_MAGIC: &[u8; 8] = b"KELVACT1";
const ACCOUNT_RECOVERY_CONTINUATION_VERSION: u32 = 1;
const ACCOUNT_RECOVERY_CONTINUATION_KEY_INFO: &[u8] =
    b"kelivo.account-recovery.continuation.mac.v1\0";
const ACCOUNT_RECOVERY_CONTINUATION_BINDING_OFFSET: usize = 12;
const ACCOUNT_RECOVERY_CONTINUATION_CANDIDATE_DIGEST_OFFSET: usize =
    ACCOUNT_RECOVERY_CONTINUATION_BINDING_OFFSET + STATE_BINDING_STRUCT_SIZE as usize;
const ACCOUNT_RECOVERY_CONTINUATION_SIGNING_KEY_OFFSET: usize =
    ACCOUNT_RECOVERY_CONTINUATION_CANDIDATE_DIGEST_OFFSET + SHA256_LENGTH;
const ACCOUNT_RECOVERY_CONTINUATION_TAG_OFFSET: usize =
    ACCOUNT_RECOVERY_CONTINUATION_SIGNING_KEY_OFFSET + crypto::DEVICE_PUBLIC_KEY_LENGTH;
pub(super) const ACCOUNT_RECOVERY_CONTINUATION_LENGTH: usize =
    ACCOUNT_RECOVERY_CONTINUATION_TAG_OFFSET + SHA256_LENGTH;

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct KelivoAccountRecoveryProofBinding {
    pub struct_size: u32,
    pub data_phase: u32,
    pub execution_handle: u64,
    pub user_id: [u8; UUID_LENGTH],
    pub device_id: [u8; UUID_LENGTH],
    pub security_generation: u32,
    pub key_epoch: u32,
    pub device_key_version: u32,
    pub recovery_capsule_version: u32,
    pub source_data_generation: u32,
    pub source_data_key_epoch: u32,
    pub source_data_rekey_operation_id: [u8; UUID_LENGTH],
    pub operation_authorization_digest: [u8; SHA256_LENGTH],
}

impl KelivoAccountRecoveryProofBinding {
    const fn empty() -> Self {
        Self {
            struct_size: 0,
            data_phase: 0,
            execution_handle: 0,
            user_id: [0; UUID_LENGTH],
            device_id: [0; UUID_LENGTH],
            security_generation: 0,
            key_epoch: 0,
            device_key_version: 0,
            recovery_capsule_version: 0,
            source_data_generation: 0,
            source_data_key_epoch: 0,
            source_data_rekey_operation_id: [0; UUID_LENGTH],
            operation_authorization_digest: [0; SHA256_LENGTH],
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct KelivoAccountRecoveryReplacementProofBinding {
    pub struct_size: u32,
    pub reserved: u32,
    pub execution_handle: u64,
    pub challenge_id: [u8; UUID_LENGTH],
    pub attempt_id: [u8; UUID_LENGTH],
    pub user_id: [u8; UUID_LENGTH],
    pub device_id: [u8; UUID_LENGTH],
    pub security_generation: u32,
    pub key_epoch: u32,
    pub membership_operation_id: [u8; UUID_LENGTH],
    pub membership_manifest_digest: [u8; SHA256_LENGTH],
    pub device_key_version: u32,
    pub recovery_capsule_version: u32,
    pub source_data_rekey_operation_id: [u8; UUID_LENGTH],
    pub ready_data_generation: u32,
    pub ready_data_key_epoch: u32,
    pub completion_proof_digest: [u8; SHA256_LENGTH],
    pub request_digest: [u8; SHA256_LENGTH],
}

impl KelivoAccountRecoveryReplacementProofBinding {
    const fn empty() -> Self {
        Self {
            struct_size: 0,
            reserved: 0,
            execution_handle: 0,
            challenge_id: [0; UUID_LENGTH],
            attempt_id: [0; UUID_LENGTH],
            user_id: [0; UUID_LENGTH],
            device_id: [0; UUID_LENGTH],
            security_generation: 0,
            key_epoch: 0,
            membership_operation_id: [0; UUID_LENGTH],
            membership_manifest_digest: [0; SHA256_LENGTH],
            device_key_version: 0,
            recovery_capsule_version: 0,
            source_data_rekey_operation_id: [0; UUID_LENGTH],
            ready_data_generation: 0,
            ready_data_key_epoch: 0,
            completion_proof_digest: [0; SHA256_LENGTH],
            request_digest: [0; SHA256_LENGTH],
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct KelivoAccountRecoveryPrepareInput {
    pub struct_size: u32,
    pub kind: u32,
    pub operation_id: [u8; UUID_LENGTH],
    pub target_auth_generation: u32,
    pub rekey_operation_id: [u8; UUID_LENGTH],
    pub completion_session_id: [u8; UUID_LENGTH],
    pub completion_session_token_digest: [u8; SHA256_LENGTH],
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct KelivoAccountRecoveryPrepareBinding {
    pub struct_size: u32,
    pub kind: u32,
    pub expected_generation: u32,
    pub expected_key_epoch: u32,
    pub next_generation: u32,
    pub next_key_epoch: u32,
    pub next_recovery_capsule_version: u32,
    pub reserved: u32,
    pub manifest_digest: [u8; SHA256_LENGTH],
    pub request_digest: [u8; SHA256_LENGTH],
}

impl KelivoAccountRecoveryPrepareBinding {
    const fn empty() -> Self {
        Self {
            struct_size: 0,
            kind: 0,
            expected_generation: 0,
            expected_key_epoch: 0,
            next_generation: 0,
            next_key_epoch: 0,
            next_recovery_capsule_version: 0,
            reserved: 0,
            manifest_digest: [0; SHA256_LENGTH],
            request_digest: [0; SHA256_LENGTH],
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct KelivoAccountRecoveryStateBinding {
    pub struct_size: u32,
    pub kind: u32,
    pub data_phase: u32,
    pub device_key_version: u32,
    pub user_id: [u8; UUID_LENGTH],
    pub device_id: [u8; UUID_LENGTH],
    pub source_key_epoch: u32,
    pub target_key_epoch: u32,
    pub source_data_generation: u32,
    pub target_data_generation: u32,
    pub membership_generation: u32,
    pub reserved: u32,
    pub membership_manifest_digest: [u8; SHA256_LENGTH],
    pub rekey_operation_id: [u8; UUID_LENGTH],
    pub operation_authorization_digest: [u8; SHA256_LENGTH],
}

const _: () = {
    assert!(size_of::<KelivoAccountRecoveryProofBinding>() == PROOF_BINDING_STRUCT_SIZE as usize);
    assert!(
        size_of::<KelivoAccountRecoveryReplacementProofBinding>()
            == REPLACEMENT_PROOF_BINDING_STRUCT_SIZE as usize
    );
    assert!(size_of::<KelivoAccountRecoveryPrepareInput>() == PREPARE_INPUT_STRUCT_SIZE as usize);
    assert!(
        size_of::<KelivoAccountRecoveryPrepareBinding>() == PREPARE_BINDING_STRUCT_SIZE as usize
    );
    assert!(size_of::<KelivoAccountRecoveryStateBinding>() == STATE_BINDING_STRUCT_SIZE as usize);
};

#[derive(Clone)]
struct CachedPreparedCommit {
    input_digest: [u8; SHA256_LENGTH],
    binding: KelivoAccountRecoveryPrepareBinding,
    state_binding: KelivoAccountRecoveryStateBinding,
    manifest: Vec<u8>,
    envelope: [u8; crypto::ARK_ENVELOPE_LENGTH],
    capsule: Option<[u8; recovery::RECOVERY_CAPSULE_LENGTH]>,
}

enum ExecutionState {
    Ready,
    Prepared(Box<CachedPreparedCommit>),
    Invalidated,
}

enum VerifiedRecoveryChallenge {
    Initial(Box<protocol::VerifiedAccountRecoveryChallenge>),
    Replacement {
        challenge: Box<protocol::VerifiedAccountRecoveryReplacementChallenge>,
        authorization: protocol::AccountRecoveryReplacementCommitAuthorization,
    },
}

#[derive(Clone, Copy)]
struct RecoveryExecutionChallenge {
    user_id: crypto::UserId,
    device_id: crypto::DeviceId,
    device_key_version: u32,
    key_epoch: u32,
    recovery_capsule_version: u32,
    data_phase: protocol::AccountRecoveryDataPhase,
    source_data_generation: u32,
    source_data_key_epoch: u32,
    source_data_rekey_operation_id: Option<[u8; UUID_LENGTH]>,
}

impl RecoveryExecutionChallenge {
    const fn initial(challenge: &protocol::VerifiedAccountRecoveryChallenge) -> Self {
        Self {
            user_id: challenge.user_id,
            device_id: challenge.device_id,
            device_key_version: challenge.device_key_version,
            key_epoch: challenge.key_epoch,
            recovery_capsule_version: challenge.recovery_capsule_version,
            data_phase: challenge.data_phase,
            source_data_generation: challenge.source_data_generation,
            source_data_key_epoch: challenge.source_data_key_epoch,
            source_data_rekey_operation_id: challenge.source_data_rekey_operation_id,
        }
    }

    const fn replacement(
        challenge: &protocol::VerifiedAccountRecoveryReplacementChallenge,
    ) -> Self {
        Self {
            user_id: challenge.user_id,
            device_id: challenge.device_id,
            device_key_version: challenge.device_key_version,
            key_epoch: challenge.key_epoch,
            recovery_capsule_version: challenge.recovery_capsule_version,
            data_phase: protocol::AccountRecoveryDataPhase::Ready,
            source_data_generation: challenge.ready_data_generation,
            source_data_key_epoch: challenge.ready_data_key_epoch,
            source_data_rekey_operation_id: None,
        }
    }
}

struct RecoveryExecution {
    device_identity: Arc<crypto::DeviceIdentity>,
    ark_handle: u64,
    target_auth_generation: u32,
    replacement_only: bool,
    verified_challenge: VerifiedRecoveryChallenge,
    challenge: RecoveryExecutionChallenge,
    history_head: recovery::VerifiedRecoveryHistoryHead,
    source_operation_authorization_digest: [u8; SHA256_LENGTH],
    context_digest: [u8; SHA256_LENGTH],
    state: Mutex<ExecutionState>,
}

impl Drop for RecoveryExecution {
    fn drop(&mut self) {
        let _ = crate::device_core::close_ark(self.ark_handle);
    }
}

struct ExecutionRegistry {
    next_sequence: u64,
    active: HashMap<u64, Arc<RecoveryExecution>>,
}

impl ExecutionRegistry {
    fn new() -> Self {
        Self {
            next_sequence: 1,
            active: HashMap::new(),
        }
    }
}

fn execution_registry() -> &'static Mutex<ExecutionRegistry> {
    static REGISTRY: OnceLock<Mutex<ExecutionRegistry>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(ExecutionRegistry::new()))
}

fn register_execution(value: RecoveryExecution) -> Result<u64, KelivoStatus> {
    let mut registry = execution_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    if registry.active.len() >= MAX_ACTIVE_RECOVERY_EXECUTIONS {
        return Err(KelivoStatus::TooManyActiveHandles);
    }
    for _ in 0..=RECOVERY_EXECUTION_SEQUENCE_MASK {
        let sequence = registry.next_sequence;
        registry.next_sequence = if sequence == RECOVERY_EXECUTION_SEQUENCE_MASK {
            1
        } else {
            sequence + 1
        };
        let handle = RECOVERY_EXECUTION_HANDLE_TAG | sequence;
        if let Entry::Vacant(entry) = registry.active.entry(handle) {
            entry.insert(Arc::new(value));
            return Ok(handle);
        }
    }
    Err(KelivoStatus::HandleSpaceExhausted)
}

fn execution_for_handle(handle: u64) -> Result<Arc<RecoveryExecution>, KelivoStatus> {
    if !is_execution_handle(handle) {
        return Err(KelivoStatus::InvalidRecoveryExecutionHandle);
    }
    execution_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .get(&handle)
        .cloned()
        .ok_or(KelivoStatus::InvalidRecoveryExecutionHandle)
}

fn close_execution(handle: u64) -> Result<(), KelivoStatus> {
    if !is_execution_handle(handle) {
        return Err(KelivoStatus::InvalidRecoveryExecutionHandle);
    }
    let removed = {
        let mut registry = execution_registry()
            .lock()
            .map_err(|_| KelivoStatus::InternalState)?;
        let value = registry
            .active
            .get(&handle)
            .ok_or(KelivoStatus::InvalidRecoveryExecutionHandle)?;
        if Arc::strong_count(value) != 1 {
            return Err(KelivoStatus::SlotInUse);
        }
        registry
            .active
            .remove(&handle)
            .ok_or(KelivoStatus::InternalState)?
    };
    drop(removed);
    Ok(())
}

fn invalidate_execution(handle: u64, execution: &Arc<RecoveryExecution>) {
    if let Ok(mut state) = execution.state.lock() {
        *state = ExecutionState::Invalidated;
    }
    if let Ok(mut registry) = execution_registry().lock() {
        registry.active.remove(&handle);
    }
}

fn is_execution_handle(handle: u64) -> bool {
    handle != 0
        && handle & HANDLE_RESERVED_MASK == 0
        && handle & HANDLE_TAG_MASK == crate::RECOVERY_HANDLE_TAG
        && handle & RECOVERY_EXECUTION_SUBTYPE != 0
        && handle & RECOVERY_EXECUTION_SEQUENCE_MASK != 0
}

/// # Safety
///
/// 所有输入指针必须覆盖声明的可读长度；输出结构、长度指针与输出缓冲区必须
/// 覆盖声明的可写范围。恢复口令只在调用期间借用，调用方负责其后续清零。
#[allow(clippy::too_many_arguments)]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_account_recovery_verify_and_prove(
    device_identity_handle: u64,
    expected_device_key_version: u32,
    expected_device_auth_generation: u32,
    media: *const u8,
    media_length: usize,
    passphrase: *const u8,
    passphrase_length: usize,
    service_origin_sha256: *const u8,
    service_origin_sha256_length: usize,
    membership_history: *const u8,
    membership_history_length: usize,
    source_capsule: *const u8,
    source_capsule_length: usize,
    current_capsule: *const u8,
    current_capsule_length: usize,
    challenge_frame: *const u8,
    challenge_frame_length: usize,
    sealed_nonce: *const u8,
    sealed_nonce_length: usize,
    recovery_token_digest: *const u8,
    recovery_token_digest_length: usize,
    expected_attempt_id: *const u8,
    expected_attempt_id_length: usize,
    expected_device_id: *const u8,
    expected_device_id_length: usize,
    expected_request_digest: *const u8,
    expected_request_digest_length: usize,
    expected_expires_at_ms: u64,
    out_binding: *mut KelivoAccountRecoveryProofBinding,
    out_nonce_proof: *mut u8,
    out_nonce_proof_capacity: usize,
    out_nonce_proof_length: *mut usize,
    out_trust_signature: *mut u8,
    out_trust_signature_capacity: usize,
    out_trust_signature_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        reset_proof_outputs(
            out_binding,
            out_nonce_proof,
            out_nonce_proof_capacity,
            out_nonce_proof_length,
            out_trust_signature,
            out_trust_signature_capacity,
            out_trust_signature_length,
        )
    } {
        return status.code();
    }
    if let Err(status) = crate::recovery::require_recovery_user_flow() {
        return status.code();
    }
    if expected_device_key_version == 0
        || expected_device_auth_generation == 0
        || expected_device_auth_generation > 0x7fff_ffff
    {
        return KelivoStatus::RecoveryChallengeInvalid.code();
    }
    let device_identity = match crate::device_core::identity_for_handle(device_identity_handle) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let media_bytes = match unsafe { read_input(media, media_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let media = match recovery::RecoveryMedia::from_bytes(media_bytes) {
        Ok(value) => value,
        Err(error) => return crate::recovery::recovery_error_status(error).code(),
    };
    let passphrase = match unsafe { read_input(passphrase, passphrase_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let origin =
        match read_fixed::<SHA256_LENGTH>(service_origin_sha256, service_origin_sha256_length) {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let history = match unsafe { read_input(membership_history, membership_history_length) } {
        Ok(value) if !value.is_empty() && value.len() <= recovery::RECOVERY_HISTORY_MAX_BYTES => {
            value
        }
        Ok(_) => return KelivoStatus::RecoveryHistoryInvalid.code(),
        Err(status) => return status.code(),
    };
    let source_capsule = match read_optional_capsule(source_capsule, source_capsule_length) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let current_capsule = match read_capsule(current_capsule, current_capsule_length) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let challenge_bytes = match unsafe { read_input(challenge_frame, challenge_frame_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let sealed_nonce = match unsafe { read_input(sealed_nonce, sealed_nonce_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let recovery_token_digest =
        match read_fixed::<SHA256_LENGTH>(recovery_token_digest, recovery_token_digest_length) {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let expected_attempt_id =
        match read_fixed::<UUID_LENGTH>(expected_attempt_id, expected_attempt_id_length) {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let expected_device_id =
        match read_fixed::<UUID_LENGTH>(expected_device_id, expected_device_id_length) {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let expected_request_digest = match read_fixed::<SHA256_LENGTH>(
        expected_request_digest,
        expected_request_digest_length,
    ) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };

    let imported = match recovery::open_recovery_media(&media, passphrase, &origin) {
        Ok(value) => value,
        Err(error) => return crate::recovery::recovery_error_status(error).code(),
    };
    let opened = match recovery::verify_recovery_history_and_open_capsules(
        &imported.identity,
        imported.user_id,
        imported.recovery_public_key_version,
        &imported.genesis,
        history,
        source_capsule.as_ref(),
        &current_capsule,
    ) {
        Ok(value) => value,
        Err(error) => return crate::recovery::recovery_error_status(error).code(),
    };
    let expected_device_id = match crypto::DeviceId::new(expected_device_id) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
    };
    let expectation = protocol::AccountRecoveryChallengeExpectation {
        attempt_id: expected_attempt_id,
        user_id: opened.history_head.user_id,
        device_id: expected_device_id,
        device_key_version: expected_device_key_version,
        device_public_keys: device_identity.public_keys(),
        security_generation: opened.history_head.security_generation,
        key_epoch: opened.history_head.key_epoch,
        membership_manifest_digest: opened.history_head.digest,
        recovery_public_key_version: opened.history_head.recovery_public_key_version,
        recovery_public_key: opened.history_head.recovery_public_key,
        recovery_capsule_version: opened.history_head.recovery_capsule_version,
        recovery_capsule_digest: opened.history_head.recovery_capsule_digest,
        expires_at_ms: expected_expires_at_ms,
        request_digest: expected_request_digest,
    };
    let challenge = match protocol::VerifiedAccountRecoveryChallenge::parse_and_bind(
        challenge_bytes,
        expectation,
    ) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
    };
    let source_operation_authorization_digest = match challenge.data_phase {
        protocol::AccountRecoveryDataPhase::Ready
            if challenge.source_data_key_epoch == challenge.key_epoch =>
        {
            [0; SHA256_LENGTH]
        }
        protocol::AccountRecoveryDataPhase::RekeyPending
            if challenge.source_data_key_epoch.checked_add(1) == Some(challenge.key_epoch) =>
        {
            let Some(source_operation_id) = challenge.source_data_rekey_operation_id else {
                return KelivoStatus::RecoveryChallengeInvalid.code();
            };
            let Some(source_operation) = source_rekey_operation(
                &opened.history_head.operations,
                source_operation_id,
                challenge.key_epoch,
            ) else {
                return KelivoStatus::RecoveryChallengeInvalid.code();
            };
            source_operation.authorization_digest
        }
        _ => return KelivoStatus::RecoveryChallengeInvalid.code(),
    };
    let nonce =
        match protocol::open_account_recovery_nonce(&imported.identity, &challenge, sealed_nonce) {
            Ok(value) => value,
            Err(protocol::AccountRecoveryProtocolError::SealedNonceAuthenticationFailed) => {
                return KelivoStatus::RecoveryChallengeAuthenticationFailed.code();
            }
            Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
        };
    let proof = match protocol::create_account_recovery_proof_material(
        challenge.as_bytes(),
        nonce.as_slice(),
        &recovery_token_digest,
    ) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
    };
    let trust_signature = match crypto::sign_account_recovery_trust_message(
        &opened.current.ark,
        AccountTrustBinding {
            user_id: challenge.user_id,
            key_epoch: challenge.key_epoch,
        },
        &proof.trust_signature_message,
    ) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::InternalState.code(),
    };
    let source = opened.source.map(|source| (source.key_epoch, source.ark));
    let ark_handle = match crate::device_core::register_recovered_ark_keyring(
        opened.current.user_id,
        source,
        opened.current.key_epoch,
        opened.current.ark,
    ) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let context_digest = recovery_context_digest(
        media_bytes,
        history,
        source_capsule.as_ref(),
        &current_capsule,
        challenge.as_bytes(),
    );
    let execution_challenge = RecoveryExecutionChallenge::initial(&challenge);
    let execution = RecoveryExecution {
        device_identity,
        ark_handle,
        target_auth_generation: expected_device_auth_generation,
        replacement_only: false,
        verified_challenge: VerifiedRecoveryChallenge::Initial(Box::new(challenge)),
        challenge: execution_challenge,
        history_head: opened.history_head,
        source_operation_authorization_digest,
        context_digest,
        state: Mutex::new(ExecutionState::Ready),
    };
    let execution_handle = match register_execution(execution) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let binding = KelivoAccountRecoveryProofBinding {
        struct_size: PROOF_BINDING_STRUCT_SIZE,
        data_phase: match challenge.data_phase {
            protocol::AccountRecoveryDataPhase::Ready => 1,
            protocol::AccountRecoveryDataPhase::RekeyPending => 2,
        },
        execution_handle,
        user_id: *challenge.user_id.as_bytes(),
        device_id: *challenge.device_id.as_bytes(),
        security_generation: challenge.security_generation,
        key_epoch: challenge.key_epoch,
        device_key_version: challenge.device_key_version,
        recovery_capsule_version: challenge.recovery_capsule_version,
        source_data_generation: challenge.source_data_generation,
        source_data_key_epoch: challenge.source_data_key_epoch,
        source_data_rekey_operation_id: challenge
            .source_data_rekey_operation_id
            .unwrap_or([0; UUID_LENGTH]),
        operation_authorization_digest: source_operation_authorization_digest,
    };
    let publish = unsafe {
        write_bytes(
            out_nonce_proof,
            out_nonce_proof_capacity,
            &proof.nonce_proof,
            out_nonce_proof_length,
        )
        .and_then(|()| {
            write_bytes(
                out_trust_signature,
                out_trust_signature_capacity,
                trust_signature.as_bytes(),
                out_trust_signature_length,
            )
        })
        .and_then(|()| write_output(out_binding, binding))
    };
    match publish {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => {
            if let Ok(execution) = execution_for_handle(execution_handle) {
                invalidate_execution(execution_handle, &execution);
            }
            status.code()
        }
    }
}

/// # Safety
///
/// 所有输入指针必须覆盖声明的可读长度；输出结构、长度指针与输出缓冲区必须
/// 覆盖声明的可写范围。恢复口令和完成证明仅在调用期间借用。
#[allow(clippy::too_many_arguments)]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_account_recovery_replacement_challenge_verify_and_prove(
    device_identity_handle: u64,
    expected_device_key_version: u32,
    expected_device_auth_generation: u32,
    media: *const u8,
    media_length: usize,
    passphrase: *const u8,
    passphrase_length: usize,
    service_origin_sha256: *const u8,
    service_origin_sha256_length: usize,
    membership_history: *const u8,
    membership_history_length: usize,
    source_capsule: *const u8,
    source_capsule_length: usize,
    current_capsule: *const u8,
    current_capsule_length: usize,
    challenge_frame: *const u8,
    challenge_frame_length: usize,
    sealed_nonce: *const u8,
    sealed_nonce_length: usize,
    completion_proof_frame: *const u8,
    completion_proof_frame_length: usize,
    completion_proof_signature: *const u8,
    completion_proof_signature_length: usize,
    recovery_token_digest: *const u8,
    recovery_token_digest_length: usize,
    expected_challenge_id: *const u8,
    expected_challenge_id_length: usize,
    expected_attempt_id: *const u8,
    expected_attempt_id_length: usize,
    expected_device_id: *const u8,
    expected_device_id_length: usize,
    expected_expires_at_ms: u64,
    out_binding: *mut KelivoAccountRecoveryReplacementProofBinding,
    out_nonce_proof: *mut u8,
    out_nonce_proof_capacity: usize,
    out_nonce_proof_length: *mut usize,
    out_trust_signature: *mut u8,
    out_trust_signature_capacity: usize,
    out_trust_signature_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        reset_replacement_proof_outputs(
            out_binding,
            out_nonce_proof,
            out_nonce_proof_capacity,
            out_nonce_proof_length,
            out_trust_signature,
            out_trust_signature_capacity,
            out_trust_signature_length,
        )
    } {
        return status.code();
    }
    if let Err(status) = crate::recovery::require_recovery_user_flow() {
        return status.code();
    }
    if expected_device_key_version == 0
        || expected_device_auth_generation == 0
        || expected_device_auth_generation > 0x7fff_ffff
    {
        return KelivoStatus::RecoveryChallengeInvalid.code();
    }
    let device_identity = match crate::device_core::identity_for_handle(device_identity_handle) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let media_bytes = match unsafe { read_input(media, media_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let media = match recovery::RecoveryMedia::from_bytes(media_bytes) {
        Ok(value) => value,
        Err(error) => return crate::recovery::recovery_error_status(error).code(),
    };
    let passphrase = match unsafe { read_input(passphrase, passphrase_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let origin =
        match read_fixed::<SHA256_LENGTH>(service_origin_sha256, service_origin_sha256_length) {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let history = match unsafe { read_input(membership_history, membership_history_length) } {
        Ok(value) if !value.is_empty() && value.len() <= recovery::RECOVERY_HISTORY_MAX_BYTES => {
            value
        }
        Ok(_) => return KelivoStatus::RecoveryHistoryInvalid.code(),
        Err(status) => return status.code(),
    };
    let source_capsule = match read_capsule(source_capsule, source_capsule_length) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let current_capsule = match read_capsule(current_capsule, current_capsule_length) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let challenge_bytes = match unsafe { read_input(challenge_frame, challenge_frame_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let sealed_nonce = match unsafe { read_input(sealed_nonce, sealed_nonce_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let completion_proof_frame =
        match unsafe { read_input(completion_proof_frame, completion_proof_frame_length) } {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let completion_proof_signature = match unsafe {
        read_input(
            completion_proof_signature,
            completion_proof_signature_length,
        )
    } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let recovery_token_digest =
        match read_fixed::<SHA256_LENGTH>(recovery_token_digest, recovery_token_digest_length) {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let expected_challenge_id =
        match read_fixed::<UUID_LENGTH>(expected_challenge_id, expected_challenge_id_length) {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let expected_attempt_id =
        match read_fixed::<UUID_LENGTH>(expected_attempt_id, expected_attempt_id_length) {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let expected_device_id =
        match read_fixed::<UUID_LENGTH>(expected_device_id, expected_device_id_length) {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let expected_device_id = match crypto::DeviceId::new(expected_device_id) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
    };

    let imported = match recovery::open_recovery_media(&media, passphrase, &origin) {
        Ok(value) => value,
        Err(error) => return crate::recovery::recovery_error_status(error).code(),
    };
    let opened = match recovery::verify_recovery_history_and_open_capsules(
        &imported.identity,
        imported.user_id,
        imported.recovery_public_key_version,
        &imported.genesis,
        history,
        Some(&source_capsule),
        &current_capsule,
    ) {
        Ok(value) => value,
        Err(error) => return crate::recovery::recovery_error_status(error).code(),
    };
    let completion_binding = match crypto::verify_and_bind_data_rekey_completion_proof(
        &device_identity.public_keys().signing,
        completion_proof_frame,
        completion_proof_signature,
    ) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
    };
    let completion_proof_digest = match crypto::data_rekey_completion_proof_digest(
        completion_proof_frame,
        completion_proof_signature,
    ) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
    };
    let source_operation_authorization_digest = match validate_replacement_completion_binding(
        &opened.history_head,
        &device_identity,
        expected_device_id,
        expected_device_key_version,
        expected_device_auth_generation,
        completion_binding,
    ) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let request_digest =
        match protocol::account_recovery_replacement_challenge_request_digest(challenge_bytes) {
            Ok(value) => value,
            Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
        };
    let expectation = protocol::AccountRecoveryReplacementChallengeExpectation {
        challenge_id: expected_challenge_id,
        attempt_id: expected_attempt_id,
        user_id: opened.history_head.user_id,
        device_id: expected_device_id,
        device_key_version: expected_device_key_version,
        device_public_keys: device_identity.public_keys(),
        membership_generation: opened.history_head.security_generation,
        key_epoch: opened.history_head.key_epoch,
        membership_operation_id: opened.history_head.operation_id,
        membership_manifest_digest: opened.history_head.digest,
        recovery_public_key_version: opened.history_head.recovery_public_key_version,
        recovery_public_key: opened.history_head.recovery_public_key,
        recovery_capsule_version: opened.history_head.recovery_capsule_version,
        recovery_capsule_digest: opened.history_head.recovery_capsule_digest,
        source_data_rekey_operation_id: completion_binding.operation_id,
        ready_data_generation: completion_binding.target_data_generation,
        ready_data_key_epoch: completion_binding.target_key_epoch,
        completion_proof_digest,
        expires_at_ms: expected_expires_at_ms,
        request_digest,
    };
    let challenge = match protocol::VerifiedAccountRecoveryReplacementChallenge::parse_and_bind(
        challenge_bytes,
        expectation,
    ) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
    };
    let nonce = match protocol::open_account_recovery_replacement_nonce(
        &imported.identity,
        &challenge,
        sealed_nonce,
    ) {
        Ok(value) => value,
        Err(protocol::AccountRecoveryProtocolError::SealedNonceAuthenticationFailed) => {
            return KelivoStatus::RecoveryChallengeAuthenticationFailed.code();
        }
        Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
    };
    let proof = match protocol::create_account_recovery_replacement_proof_material(
        challenge.as_bytes(),
        nonce.as_slice(),
        &recovery_token_digest,
    ) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RecoveryChallengeInvalid.code(),
    };
    let trust_signature = match crypto::sign_account_recovery_trust_message(
        &opened.current.ark,
        AccountTrustBinding {
            user_id: challenge.user_id,
            key_epoch: challenge.key_epoch,
        },
        &proof.trust_signature_message,
    ) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::InternalState.code(),
    };
    let commit_authorization =
        protocol::AccountRecoveryReplacementCommitAuthorization::from_verified_proof(
            &challenge,
            &proof,
            &trust_signature,
        );
    let source = opened.source.map(|source| (source.key_epoch, source.ark));
    let ark_handle = match crate::device_core::register_recovered_ark_keyring(
        opened.current.user_id,
        source,
        opened.current.key_epoch,
        opened.current.ark,
    ) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let context_digest = recovery_replacement_context_digest(
        media_bytes,
        history,
        &source_capsule,
        &current_capsule,
        challenge.as_bytes(),
        completion_proof_frame,
        completion_proof_signature,
    );
    let execution_challenge = RecoveryExecutionChallenge::replacement(&challenge);
    let execution = RecoveryExecution {
        device_identity,
        ark_handle,
        target_auth_generation: expected_device_auth_generation,
        replacement_only: true,
        verified_challenge: VerifiedRecoveryChallenge::Replacement {
            challenge: Box::new(challenge),
            authorization: commit_authorization,
        },
        challenge: execution_challenge,
        history_head: opened.history_head,
        source_operation_authorization_digest,
        context_digest,
        state: Mutex::new(ExecutionState::Ready),
    };
    let execution_handle = match register_execution(execution) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let binding = KelivoAccountRecoveryReplacementProofBinding {
        struct_size: REPLACEMENT_PROOF_BINDING_STRUCT_SIZE,
        reserved: 0,
        execution_handle,
        challenge_id: challenge.challenge_id,
        attempt_id: challenge.attempt_id,
        user_id: *challenge.user_id.as_bytes(),
        device_id: *challenge.device_id.as_bytes(),
        security_generation: challenge.membership_generation,
        key_epoch: challenge.key_epoch,
        membership_operation_id: challenge.membership_operation_id,
        membership_manifest_digest: challenge.membership_manifest_digest,
        device_key_version: challenge.device_key_version,
        recovery_capsule_version: challenge.recovery_capsule_version,
        source_data_rekey_operation_id: challenge.source_data_rekey_operation_id,
        ready_data_generation: challenge.ready_data_generation,
        ready_data_key_epoch: challenge.ready_data_key_epoch,
        completion_proof_digest: challenge.completion_proof_digest,
        request_digest: challenge.request_digest,
    };
    let publish = unsafe {
        write_bytes(
            out_nonce_proof,
            out_nonce_proof_capacity,
            &proof.nonce_proof,
            out_nonce_proof_length,
        )
        .and_then(|()| {
            write_bytes(
                out_trust_signature,
                out_trust_signature_capacity,
                trust_signature.as_bytes(),
                out_trust_signature_length,
            )
        })
        .and_then(|()| write_output(out_binding, binding))
    };
    match publish {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => {
            if let Ok(execution) = execution_for_handle(execution_handle) {
                invalidate_execution(execution_handle, &execution);
            }
            status.code()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_account_recovery_execution_close(handle: u64) -> i32 {
    match close_execution(handle) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

/// # Safety
///
/// `input` 必须指向完整的固定版结构；所有输出结构、长度指针与输出缓冲区
/// 必须覆盖声明的可写范围，且在调用期间不得与输入内存重叠。
#[allow(clippy::too_many_arguments)]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_account_recovery_prepare_commit(
    execution_handle: u64,
    input: *const KelivoAccountRecoveryPrepareInput,
    out_binding: *mut KelivoAccountRecoveryPrepareBinding,
    out_manifest: *mut u8,
    out_manifest_capacity: usize,
    out_manifest_length: *mut usize,
    out_envelope: *mut u8,
    out_envelope_capacity: usize,
    out_envelope_length: *mut usize,
    out_capsule: *mut u8,
    out_capsule_capacity: usize,
    out_capsule_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        reset_prepare_outputs(
            out_binding,
            out_manifest,
            out_manifest_capacity,
            out_manifest_length,
            out_envelope,
            out_envelope_capacity,
            out_envelope_length,
            out_capsule,
            out_capsule_capacity,
            out_capsule_length,
        )
    } {
        return status.code();
    }
    if let Err(status) = crate::recovery::require_recovery_user_flow() {
        return status.code();
    }
    let input = match unsafe { read_prepare_input(input) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let execution = match execution_for_handle(execution_handle) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    if input.target_auth_generation != execution.target_auth_generation {
        invalidate_execution(execution_handle, &execution);
        return KelivoStatus::RecoveryPrepareInvalid.code();
    }
    let protocol_input = match protocol_prepare_input(input) {
        Ok(value) => value,
        Err(status) => {
            invalidate_execution(execution_handle, &execution);
            return status.code();
        }
    };
    if execution.replacement_only && input.kind != PREPARE_KIND_REPLACEMENT {
        invalidate_execution(execution_handle, &execution);
        return KelivoStatus::RecoveryPrepareInvalid.code();
    }
    let input_digest = prepare_input_digest(&execution.context_digest, &input);
    let cached = {
        let mut state = match execution.state.lock() {
            Ok(value) => value,
            Err(_) => {
                invalidate_execution(execution_handle, &execution);
                return KelivoStatus::InternalState.code();
            }
        };
        match &*state {
            ExecutionState::Prepared(cached) if cached.input_digest == input_digest => {
                cached.as_ref().clone()
            }
            ExecutionState::Prepared(_) | ExecutionState::Invalidated => {
                *state = ExecutionState::Invalidated;
                drop(state);
                invalidate_execution(execution_handle, &execution);
                return KelivoStatus::RecoveryPrepareInvalid.code();
            }
            ExecutionState::Ready => {
                let current_ark = match crate::device_core::ark_for_account_handle(
                    execution.ark_handle,
                    execution.challenge.user_id,
                    execution.challenge.key_epoch,
                ) {
                    Ok(value) => value,
                    Err(status) => {
                        *state = ExecutionState::Invalidated;
                        drop(state);
                        invalidate_execution(execution_handle, &execution);
                        return status.code();
                    }
                };
                let mut rng = match kelivo_secure_core_protocol::system_rng() {
                    Ok(value) => value,
                    Err(_) => return KelivoStatus::RandomSourceFailure.code(),
                };
                let prepared_result = match &execution.verified_challenge {
                    VerifiedRecoveryChallenge::Initial(challenge) => {
                        protocol::prepare_account_recovery_commit(
                            &mut rng,
                            &current_ark,
                            &execution.device_identity,
                            challenge,
                            &execution.history_head,
                            protocol_input,
                        )
                    }
                    VerifiedRecoveryChallenge::Replacement {
                        challenge,
                        authorization,
                    } => protocol::prepare_account_recovery_replacement_commit(
                        &mut rng,
                        &current_ark,
                        &execution.device_identity,
                        challenge,
                        authorization,
                        &execution.history_head,
                        protocol_input,
                    ),
                };
                let prepared = match prepared_result {
                    Ok(value) => value,
                    Err(_) => {
                        *state = ExecutionState::Invalidated;
                        drop(state);
                        invalidate_execution(execution_handle, &execution);
                        return KelivoStatus::RecoveryPrepareInvalid.code();
                    }
                };
                if let Some(next_ark) = prepared.next_ark
                    && let Err(status) = crate::device_core::add_ark_epoch(
                        execution.ark_handle,
                        execution.challenge.user_id,
                        prepared.next_key_epoch,
                        next_ark,
                    )
                {
                    *state = ExecutionState::Invalidated;
                    drop(state);
                    invalidate_execution(execution_handle, &execution);
                    return status.code();
                }
                let capsule = prepared
                    .next_recovery_capsule
                    .as_ref()
                    .map(|value| *value.as_bytes());
                let binding = KelivoAccountRecoveryPrepareBinding {
                    struct_size: PREPARE_BINDING_STRUCT_SIZE,
                    kind: input.kind,
                    expected_generation: prepared.expected_generation,
                    expected_key_epoch: prepared.expected_key_epoch,
                    next_generation: prepared.next_generation,
                    next_key_epoch: prepared.next_key_epoch,
                    next_recovery_capsule_version: capsule
                        .as_ref()
                        .map_or(0, |_| execution.challenge.recovery_capsule_version + 1),
                    reserved: 0,
                    manifest_digest: prepared.manifest_digest,
                    request_digest: prepared.request_digest,
                };
                let state_binding = prepared_state_binding(&execution, input, binding);
                let cached = CachedPreparedCommit {
                    input_digest,
                    binding,
                    state_binding,
                    manifest: prepared.manifest,
                    envelope: *prepared.envelope.as_bytes(),
                    capsule,
                };
                *state = ExecutionState::Prepared(Box::new(cached.clone()));
                cached
            }
        }
    };
    match unsafe {
        publish_prepared(
            &cached,
            out_binding,
            out_manifest,
            out_manifest_capacity,
            out_manifest_length,
            out_envelope,
            out_envelope_capacity,
            out_envelope_length,
            out_capsule,
            out_capsule_capacity,
            out_capsule_length,
        )
    } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

/// # Safety
///
/// `expected` 必须指向完整结构；三个输出缓冲区与长度指针必须可写且互不重叠。
#[allow(clippy::too_many_arguments)]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_account_recovery_device_states_prepare(
    execution_handle: u64,
    key_handle: u64,
    expected: *const KelivoAccountRecoveryStateBinding,
    out_unpruned_blob: *mut u8,
    out_unpruned_blob_capacity: usize,
    out_unpruned_blob_length: *mut usize,
    out_pruned_candidate: *mut u8,
    out_pruned_candidate_capacity: usize,
    out_pruned_candidate_length: *mut usize,
    out_continuation: *mut u8,
    out_continuation_capacity: usize,
    out_continuation_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        reset_state_prepare_outputs(
            out_unpruned_blob,
            out_unpruned_blob_capacity,
            out_unpruned_blob_length,
            out_pruned_candidate,
            out_pruned_candidate_capacity,
            out_pruned_candidate_length,
            out_continuation,
            out_continuation_capacity,
            out_continuation_length,
        )
    } {
        return status.code();
    }
    if let Err(status) = crate::recovery::require_recovery_user_flow() {
        return status.code();
    }
    let expected = match unsafe { read_state_binding(expected) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let execution = match execution_for_handle(execution_handle) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let state = match execution.state.lock() {
        Ok(value) => value,
        Err(_) => return KelivoStatus::InternalState.code(),
    };
    let cached = match &*state {
        ExecutionState::Prepared(value) => value.as_ref(),
        ExecutionState::Ready | ExecutionState::Invalidated => {
            return KelivoStatus::RecoveryPrepareInvalid.code();
        }
    };
    if validate_prepared_state_binding(&execution, cached, expected).is_err() {
        return KelivoStatus::RecoveryPrepareInvalid.code();
    }
    let context = match recovery_device_state_context(expected) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let (unpruned, pruned) = match crate::device_core::prepare_recovery_device_states(
        key_handle,
        &execution.device_identity,
        execution.ark_handle,
        context,
    ) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let continuation = match create_account_recovery_continuation(
        key_handle,
        expected,
        pruned.as_bytes(),
        &execution.device_identity.public_keys().signing,
    ) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    unsafe {
        write_bytes(
            out_unpruned_blob,
            out_unpruned_blob_capacity,
            unpruned.as_bytes(),
            out_unpruned_blob_length,
        )
        .and_then(|()| {
            write_bytes(
                out_pruned_candidate,
                out_pruned_candidate_capacity,
                pruned.as_bytes(),
                out_pruned_candidate_length,
            )
        })
        .and_then(|()| {
            write_bytes(
                out_continuation,
                out_continuation_capacity,
                &continuation,
                out_continuation_length,
            )
        })
        .expect("已清零且验证的恢复设备状态候选输出必须可写")
    };
    KelivoStatus::Ok.code()
}

/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出缓冲区与长度指针必须可写且互不重叠。
#[allow(clippy::too_many_arguments)]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_account_recovery_device_state_prune_and_activate(
    key_handle: u64,
    continuation: *const u8,
    continuation_length: usize,
    expected: *const KelivoAccountRecoveryStateBinding,
    pruned_candidate: *const u8,
    pruned_candidate_length: usize,
    completion_proof_frame: *const u8,
    completion_proof_frame_length: usize,
    completion_proof_signature: *const u8,
    completion_proof_signature_length: usize,
    expected_completion_proof_digest: *const u8,
    expected_completion_proof_digest_length: usize,
    out_blob: *mut u8,
    out_blob_capacity: usize,
    out_blob_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        reset_fixed_blob_output(
            out_blob,
            out_blob_capacity,
            out_blob_length,
            crate::device_core::DEVICE_STATE_BLOB_LENGTH,
        )
    } {
        return status.code();
    }
    if let Err(status) = crate::recovery::require_recovery_user_flow() {
        return status.code();
    }
    let expected = match unsafe { read_state_binding(expected) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let continuation = match unsafe { read_input(continuation, continuation_length) } {
        Ok(value) if value.len() == ACCOUNT_RECOVERY_CONTINUATION_LENGTH => value,
        Ok(_) => return KelivoStatus::RecoveryPrepareInvalid.code(),
        Err(status) => return status.code(),
    };
    let pruned_candidate = match unsafe { read_input(pruned_candidate, pruned_candidate_length) } {
        Ok(value) if value.len() == crate::device_core::DEVICE_STATE_BLOB_LENGTH => value,
        Ok(_) => return KelivoStatus::RecoveryPrepareInvalid.code(),
        Err(status) => return status.code(),
    };
    let proof_frame =
        match unsafe { read_input(completion_proof_frame, completion_proof_frame_length) } {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let proof_signature = match unsafe {
        read_input(
            completion_proof_signature,
            completion_proof_signature_length,
        )
    } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let proof_digest = match unsafe {
        read_input(
            expected_completion_proof_digest,
            expected_completion_proof_digest_length,
        )
    } {
        Ok(value) if value.len() == SHA256_LENGTH => value,
        Ok(_) => return KelivoStatus::RecoveryPrepareInvalid.code(),
        Err(status) => return status.code(),
    };
    let context = match recovery_device_state_context(expected) {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RecoveryPrepareInvalid.code(),
    };
    let signing_public_key = match validate_account_recovery_continuation(
        key_handle,
        continuation,
        expected,
        pruned_candidate,
    ) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    if validate_completion_proof(
        &signing_public_key,
        context,
        expected,
        proof_frame,
        proof_signature,
        proof_digest,
    )
    .is_err()
    {
        return KelivoStatus::RecoveryPrepareInvalid.code();
    }
    let blob = match crate::device_core::validate_prepared_recovery_device_state(
        key_handle,
        &signing_public_key,
        context,
        pruned_candidate,
    ) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    unsafe {
        write_bytes(
            out_blob,
            out_blob_capacity,
            blob.as_bytes(),
            out_blob_length,
        )
        .expect("已清零且验证的裁剪设备状态输出必须可写")
    };
    KelivoStatus::Ok.code()
}

fn recovery_device_state_context(
    binding: KelivoAccountRecoveryStateBinding,
) -> Result<crate::device_core::RecoveryDeviceStateContext, KelivoStatus> {
    validate_persisted_state_binding(binding)?;
    Ok(crate::device_core::RecoveryDeviceStateContext {
        user_id: crypto::UserId::new(binding.user_id)
            .map_err(|_| KelivoStatus::RecoveryPrepareInvalid)?,
        device_id: crypto::DeviceId::new(binding.device_id)
            .map_err(|_| KelivoStatus::RecoveryPrepareInvalid)?,
        device_key_version: binding.device_key_version,
        source_key_epoch: binding.source_key_epoch,
        target_key_epoch: binding.target_key_epoch,
    })
}

fn validate_prepared_state_binding(
    execution: &RecoveryExecution,
    cached: &CachedPreparedCommit,
    expected: KelivoAccountRecoveryStateBinding,
) -> Result<(), KelivoStatus> {
    validate_common_state_binding(execution, expected)?;
    if expected != cached.state_binding {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    match expected.kind {
        PREPARE_KIND_RESUME
            if expected.data_phase == 2
                && expected.target_key_epoch == execution.challenge.key_epoch
                && expected.source_key_epoch == execution.challenge.source_data_key_epoch
                && execution.challenge.source_data_rekey_operation_id
                    == Some(expected.rekey_operation_id)
                && expected.operation_authorization_digest
                    == execution.source_operation_authorization_digest =>
        {
            Ok(())
        }
        PREPARE_KIND_REPLACEMENT
            if expected.data_phase == 1
                && expected.source_key_epoch == execution.challenge.key_epoch
                && expected.source_key_epoch == execution.challenge.source_data_key_epoch
                && execution.challenge.source_data_rekey_operation_id.is_none()
                && expected.operation_authorization_digest == [0; SHA256_LENGTH] =>
        {
            Ok(())
        }
        _ => Err(KelivoStatus::RecoveryPrepareInvalid),
    }
}

fn validate_common_state_binding(
    execution: &RecoveryExecution,
    expected: KelivoAccountRecoveryStateBinding,
) -> Result<(), KelivoStatus> {
    if (execution.replacement_only && expected.kind != PREPARE_KIND_REPLACEMENT)
        || expected.struct_size != STATE_BINDING_STRUCT_SIZE
        || expected.reserved != 0
        || expected.user_id != *execution.challenge.user_id.as_bytes()
        || expected.device_id != *execution.challenge.device_id.as_bytes()
        || expected.device_key_version != execution.challenge.device_key_version
        || expected.source_key_epoch.checked_add(1) != Some(expected.target_key_epoch)
        || expected.source_data_generation == 0
        || expected.source_data_generation.checked_add(1) != Some(expected.target_data_generation)
        || expected.target_data_generation > 0x7fff_ffff
        || expected.membership_generation == 0
        || expected.membership_generation > 0x7fff_ffff
    {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    Ok(())
}

fn validate_persisted_state_binding(
    expected: KelivoAccountRecoveryStateBinding,
) -> Result<(), KelivoStatus> {
    let kind_and_phase_valid = match expected.kind {
        PREPARE_KIND_RESUME => expected.data_phase == 2,
        PREPARE_KIND_REPLACEMENT => {
            expected.data_phase == 1
                && expected.operation_authorization_digest == [0; SHA256_LENGTH]
        }
        _ => false,
    };
    if !kind_and_phase_valid
        || expected.struct_size != STATE_BINDING_STRUCT_SIZE
        || expected.reserved != 0
        || expected.device_key_version == 0
        || expected.source_key_epoch == 0
        || expected.source_key_epoch.checked_add(1) != Some(expected.target_key_epoch)
        || expected.source_data_generation == 0
        || expected.source_data_generation.checked_add(1) != Some(expected.target_data_generation)
        || expected.target_data_generation > 0x7fff_ffff
        || expected.membership_generation == 0
        || expected.membership_generation > 0x7fff_ffff
    {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    Ok(())
}

fn create_account_recovery_continuation(
    key_handle: u64,
    binding: KelivoAccountRecoveryStateBinding,
    pruned_candidate: &[u8],
    signing_public_key: &crypto::DeviceSigningPublicKey,
) -> Result<[u8; ACCOUNT_RECOVERY_CONTINUATION_LENGTH], KelivoStatus> {
    let mut continuation = [0_u8; ACCOUNT_RECOVERY_CONTINUATION_LENGTH];
    continuation[..ACCOUNT_RECOVERY_CONTINUATION_MAGIC.len()]
        .copy_from_slice(ACCOUNT_RECOVERY_CONTINUATION_MAGIC);
    continuation[8..12].copy_from_slice(&ACCOUNT_RECOVERY_CONTINUATION_VERSION.to_be_bytes());
    continuation[ACCOUNT_RECOVERY_CONTINUATION_BINDING_OFFSET
        ..ACCOUNT_RECOVERY_CONTINUATION_CANDIDATE_DIGEST_OFFSET]
        .copy_from_slice(&canonical_state_binding(binding));
    let candidate_digest = Sha256::digest(pruned_candidate);
    continuation[ACCOUNT_RECOVERY_CONTINUATION_CANDIDATE_DIGEST_OFFSET
        ..ACCOUNT_RECOVERY_CONTINUATION_SIGNING_KEY_OFFSET]
        .copy_from_slice(&candidate_digest);
    continuation[ACCOUNT_RECOVERY_CONTINUATION_SIGNING_KEY_OFFSET
        ..ACCOUNT_RECOVERY_CONTINUATION_TAG_OFFSET]
        .copy_from_slice(signing_public_key.as_bytes());
    let tag = account_recovery_continuation_tag(
        key_handle,
        &continuation[..ACCOUNT_RECOVERY_CONTINUATION_TAG_OFFSET],
    )?;
    continuation[ACCOUNT_RECOVERY_CONTINUATION_TAG_OFFSET..].copy_from_slice(&tag);
    Ok(continuation)
}

fn validate_account_recovery_continuation(
    key_handle: u64,
    continuation: &[u8],
    expected: KelivoAccountRecoveryStateBinding,
    pruned_candidate: &[u8],
) -> Result<crypto::DeviceSigningPublicKey, KelivoStatus> {
    if continuation.len() != ACCOUNT_RECOVERY_CONTINUATION_LENGTH {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    let actual_tag = account_recovery_continuation_tag(
        key_handle,
        &continuation[..ACCOUNT_RECOVERY_CONTINUATION_TAG_OFFSET],
    )?;
    if !bool::from(
        actual_tag
            .as_slice()
            .ct_eq(&continuation[ACCOUNT_RECOVERY_CONTINUATION_TAG_OFFSET..]),
    ) || continuation[..ACCOUNT_RECOVERY_CONTINUATION_MAGIC.len()]
        != ACCOUNT_RECOVERY_CONTINUATION_MAGIC[..]
        || continuation[8..12] != ACCOUNT_RECOVERY_CONTINUATION_VERSION.to_be_bytes()
    {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    let binding = canonical_state_binding(expected);
    if !bool::from(binding.as_slice().ct_eq(
        &continuation[ACCOUNT_RECOVERY_CONTINUATION_BINDING_OFFSET
            ..ACCOUNT_RECOVERY_CONTINUATION_CANDIDATE_DIGEST_OFFSET],
    )) {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    let candidate_digest = Sha256::digest(pruned_candidate);
    if !bool::from(candidate_digest.as_slice().ct_eq(
        &continuation[ACCOUNT_RECOVERY_CONTINUATION_CANDIDATE_DIGEST_OFFSET
            ..ACCOUNT_RECOVERY_CONTINUATION_SIGNING_KEY_OFFSET],
    )) {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    let signing_key_bytes = continuation[ACCOUNT_RECOVERY_CONTINUATION_SIGNING_KEY_OFFSET
        ..ACCOUNT_RECOVERY_CONTINUATION_TAG_OFFSET]
        .try_into()
        .map_err(|_| KelivoStatus::RecoveryPrepareInvalid)?;
    crypto::DeviceSigningPublicKey::from_bytes(signing_key_bytes)
        .map_err(|_| KelivoStatus::RecoveryPrepareInvalid)
}

fn account_recovery_continuation_tag(
    key_handle: u64,
    payload: &[u8],
) -> Result<[u8; SHA256_LENGTH], KelivoStatus> {
    let key = key_for_handle(key_handle)?;
    let mut mac_key = Zeroizing::new([0_u8; SHA256_LENGTH]);
    Hkdf::<Sha256>::new(None, master_key(&key)?)
        .expand(
            ACCOUNT_RECOVERY_CONTINUATION_KEY_INFO,
            mac_key.as_mut_slice(),
        )
        .map_err(|_| KelivoStatus::InternalState)?;
    let mut mac = <Hmac<Sha256> as HmacKeyInit>::new_from_slice(mac_key.as_slice())
        .map_err(|_| KelivoStatus::InternalState)?;
    mac.update(payload);
    let digest = mac.finalize().into_bytes();
    Ok(digest.into())
}

fn canonical_state_binding(
    binding: KelivoAccountRecoveryStateBinding,
) -> [u8; STATE_BINDING_STRUCT_SIZE as usize] {
    let mut output = [0_u8; STATE_BINDING_STRUCT_SIZE as usize];
    write_u32_be(&mut output, 0, binding.struct_size);
    write_u32_be(&mut output, 4, binding.kind);
    write_u32_be(&mut output, 8, binding.data_phase);
    write_u32_be(&mut output, 12, binding.device_key_version);
    output[16..32].copy_from_slice(&binding.user_id);
    output[32..48].copy_from_slice(&binding.device_id);
    write_u32_be(&mut output, 48, binding.source_key_epoch);
    write_u32_be(&mut output, 52, binding.target_key_epoch);
    write_u32_be(&mut output, 56, binding.source_data_generation);
    write_u32_be(&mut output, 60, binding.target_data_generation);
    write_u32_be(&mut output, 64, binding.membership_generation);
    write_u32_be(&mut output, 68, binding.reserved);
    output[72..104].copy_from_slice(&binding.membership_manifest_digest);
    output[104..120].copy_from_slice(&binding.rekey_operation_id);
    output[120..152].copy_from_slice(&binding.operation_authorization_digest);
    output
}

fn write_u32_be(output: &mut [u8], offset: usize, value: u32) {
    output[offset..offset + 4].copy_from_slice(&value.to_be_bytes());
}

fn validate_completion_proof(
    signing_public_key: &crypto::DeviceSigningPublicKey,
    context: crate::device_core::RecoveryDeviceStateContext,
    expected: KelivoAccountRecoveryStateBinding,
    proof_frame: &[u8],
    proof_signature: &[u8],
    expected_proof_digest: &[u8],
) -> Result<(), KelivoStatus> {
    let binding = crypto::verify_and_bind_data_rekey_completion_proof(
        signing_public_key,
        proof_frame,
        proof_signature,
    )
    .map_err(|_| KelivoStatus::RecoveryPrepareInvalid)?;
    if binding.operation_id != expected.rekey_operation_id
        || binding.user_id != context.user_id
        || binding.issuer_device_id != context.device_id
        || binding.source_data_generation != expected.source_data_generation
        || binding.target_data_generation != expected.target_data_generation
        || binding.source_key_epoch != expected.source_key_epoch
        || binding.target_key_epoch != expected.target_key_epoch
        || binding.membership_generation != expected.membership_generation
        || binding.membership_manifest_digest != expected.membership_manifest_digest
    {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    let actual_digest = crypto::data_rekey_completion_proof_digest(proof_frame, proof_signature)
        .map_err(|_| KelivoStatus::RecoveryPrepareInvalid)?;
    if !same_bytes(&actual_digest, expected_proof_digest) {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    Ok(())
}

fn validate_replacement_completion_binding(
    history: &recovery::VerifiedRecoveryHistoryHead,
    device_identity: &crypto::DeviceIdentity,
    expected_device_id: crypto::DeviceId,
    expected_device_key_version: u32,
    expected_device_auth_generation: u32,
    completion: crypto::DataRekeyCompletionProofBinding,
) -> Result<[u8; SHA256_LENGTH], KelivoStatus> {
    if history.operation_kind != 4
        || history.issuer_device_id != expected_device_id
        || history.subject_device_id != expected_device_id
        || completion.user_id != history.user_id
        || completion.issuer_device_id != expected_device_id
        || completion.target_key_epoch != history.key_epoch
        || completion.membership_generation != history.security_generation
        || completion.membership_manifest_digest != history.digest
    {
        return Err(KelivoStatus::RecoveryChallengeInvalid);
    }
    let member = history
        .members
        .iter()
        .find(|member| member.device_id == expected_device_id)
        .ok_or(KelivoStatus::RecoveryChallengeInvalid)?;
    if member.key_version != expected_device_key_version
        || member.auth_generation != expected_device_auth_generation
        || member.signing_public_key != device_identity.public_keys().signing
        || member.key_agreement_public_key != device_identity.public_keys().key_agreement
    {
        return Err(KelivoStatus::RecoveryChallengeInvalid);
    }
    let source = source_rekey_operation(
        &history.operations,
        completion.operation_id,
        completion.target_key_epoch,
    )
    .ok_or(KelivoStatus::RecoveryChallengeInvalid)?;
    Ok(source.authorization_digest)
}

unsafe fn read_state_binding(
    input: *const KelivoAccountRecoveryStateBinding,
) -> Result<KelivoAccountRecoveryStateBinding, KelivoStatus> {
    if input.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    let value = unsafe { input.read_unaligned() };
    if value.struct_size != STATE_BINDING_STRUCT_SIZE || value.reserved != 0 {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    Ok(value)
}

unsafe fn reset_fixed_blob_output(
    output: *mut u8,
    capacity: usize,
    out_length: *mut usize,
    expected_length: usize,
) -> Result<(), KelivoStatus> {
    unsafe { reset_bytes(output, capacity, expected_length, out_length)? };
    if capacity < expected_length {
        unsafe { write_output(out_length, expected_length)? };
        return Err(KelivoStatus::OutputBufferTooSmall);
    }
    if output.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
unsafe fn reset_state_prepare_outputs(
    out_unpruned_blob: *mut u8,
    out_unpruned_blob_capacity: usize,
    out_unpruned_blob_length: *mut usize,
    out_pruned_candidate: *mut u8,
    out_pruned_candidate_capacity: usize,
    out_pruned_candidate_length: *mut usize,
    out_continuation: *mut u8,
    out_continuation_capacity: usize,
    out_continuation_length: *mut usize,
) -> Result<(), KelivoStatus> {
    let state_length = crate::device_core::DEVICE_STATE_BLOB_LENGTH;
    unsafe {
        reset_bytes(
            out_unpruned_blob,
            out_unpruned_blob_capacity,
            state_length,
            out_unpruned_blob_length,
        )?;
        reset_bytes(
            out_pruned_candidate,
            out_pruned_candidate_capacity,
            state_length,
            out_pruned_candidate_length,
        )?;
        reset_bytes(
            out_continuation,
            out_continuation_capacity,
            ACCOUNT_RECOVERY_CONTINUATION_LENGTH,
            out_continuation_length,
        )?;
    }
    if out_unpruned_blob_capacity < state_length
        || out_pruned_candidate_capacity < state_length
        || out_continuation_capacity < ACCOUNT_RECOVERY_CONTINUATION_LENGTH
    {
        unsafe {
            write_output(out_unpruned_blob_length, state_length)?;
            write_output(out_pruned_candidate_length, state_length)?;
            write_output(
                out_continuation_length,
                ACCOUNT_RECOVERY_CONTINUATION_LENGTH,
            )?;
        }
        return Err(KelivoStatus::OutputBufferTooSmall);
    }
    if out_unpruned_blob.is_null() || out_pruned_candidate.is_null() || out_continuation.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    Ok(())
}

fn same_bytes(left: &[u8], right: &[u8]) -> bool {
    if left.len() != right.len() {
        return false;
    }
    left.iter()
        .zip(right)
        .fold(0_u8, |difference, (left, right)| {
            difference | (left ^ right)
        })
        == 0
}

fn protocol_prepare_input(
    input: KelivoAccountRecoveryPrepareInput,
) -> Result<protocol::AccountRecoveryPrepareInput, KelivoStatus> {
    let zero_uuid = [0_u8; UUID_LENGTH];
    let zero_digest = [0_u8; SHA256_LENGTH];
    match input.kind {
        PREPARE_KIND_RESUME
            if input.completion_session_id == zero_uuid
                && input.completion_session_token_digest == zero_digest =>
        {
            Ok(protocol::AccountRecoveryPrepareInput {
                kind: protocol::AccountRecoveryCommitKind::Resume,
                operation_id: input.operation_id,
                target_auth_generation: input.target_auth_generation,
                rekey_operation_id: Some(input.rekey_operation_id),
                completion_session_id: None,
                completion_session_token_digest: None,
            })
        }
        PREPARE_KIND_REPLACEMENT if input.rekey_operation_id == zero_uuid => {
            Ok(protocol::AccountRecoveryPrepareInput {
                kind: protocol::AccountRecoveryCommitKind::Replacement,
                operation_id: input.operation_id,
                target_auth_generation: input.target_auth_generation,
                rekey_operation_id: None,
                completion_session_id: Some(input.completion_session_id),
                completion_session_token_digest: Some(input.completion_session_token_digest),
            })
        }
        _ => Err(KelivoStatus::RecoveryPrepareInvalid),
    }
}

fn prepared_state_binding(
    execution: &RecoveryExecution,
    input: KelivoAccountRecoveryPrepareInput,
    prepared: KelivoAccountRecoveryPrepareBinding,
) -> KelivoAccountRecoveryStateBinding {
    let (rekey_operation_id, operation_authorization_digest) = match input.kind {
        PREPARE_KIND_RESUME => (
            input.rekey_operation_id,
            execution.source_operation_authorization_digest,
        ),
        PREPARE_KIND_REPLACEMENT => (input.operation_id, [0; SHA256_LENGTH]),
        _ => ([0; UUID_LENGTH], [0; SHA256_LENGTH]),
    };
    KelivoAccountRecoveryStateBinding {
        struct_size: STATE_BINDING_STRUCT_SIZE,
        kind: input.kind,
        data_phase: recovery_data_phase_code(execution.challenge.data_phase),
        device_key_version: execution.challenge.device_key_version,
        user_id: *execution.challenge.user_id.as_bytes(),
        device_id: *execution.challenge.device_id.as_bytes(),
        source_key_epoch: execution.challenge.source_data_key_epoch,
        target_key_epoch: prepared.next_key_epoch,
        source_data_generation: execution.challenge.source_data_generation,
        target_data_generation: execution
            .challenge
            .source_data_generation
            .checked_add(1)
            .unwrap_or(0),
        membership_generation: prepared.next_generation,
        reserved: 0,
        membership_manifest_digest: prepared.manifest_digest,
        rekey_operation_id,
        operation_authorization_digest,
    }
}

const fn recovery_data_phase_code(value: protocol::AccountRecoveryDataPhase) -> u32 {
    match value {
        protocol::AccountRecoveryDataPhase::Ready => 1,
        protocol::AccountRecoveryDataPhase::RekeyPending => 2,
    }
}

fn recovery_context_digest(
    media: &[u8],
    history: &[u8],
    source_capsule: Option<&recovery::RecoveryCapsule>,
    current_capsule: &recovery::RecoveryCapsule,
    challenge: &[u8],
) -> [u8; SHA256_LENGTH] {
    let mut digest = Sha256::new();
    digest.update(b"kelivo.account-recovery.execution-context.v1\0");
    for value in [
        media,
        history,
        source_capsule.map_or(&[][..], |value| value.as_bytes()),
        current_capsule.as_bytes(),
        challenge,
    ] {
        digest.update((value.len() as u64).to_be_bytes());
        digest.update(value);
    }
    digest.finalize().into()
}

fn recovery_replacement_context_digest(
    media: &[u8],
    history: &[u8],
    source_capsule: &recovery::RecoveryCapsule,
    current_capsule: &recovery::RecoveryCapsule,
    challenge: &[u8],
    completion_proof_frame: &[u8],
    completion_proof_signature: &[u8],
) -> [u8; SHA256_LENGTH] {
    let mut digest = Sha256::new();
    digest.update(b"kelivo.account-recovery.replacement-execution-context.v1\0");
    for value in [
        media,
        history,
        source_capsule.as_bytes(),
        current_capsule.as_bytes(),
        challenge,
        completion_proof_frame,
        completion_proof_signature,
    ] {
        digest.update((value.len() as u64).to_be_bytes());
        digest.update(value);
    }
    digest.finalize().into()
}

fn source_rekey_operation(
    operations: &[recovery::RecoveryHistoryOperation],
    operation_id: [u8; UUID_LENGTH],
    target_key_epoch: u32,
) -> Option<&recovery::RecoveryHistoryOperation> {
    let index = operations
        .iter()
        .position(|operation| operation.operation_id == operation_id)?;
    let source = &operations[index];
    if !matches!(source.kind, 3 | 5) || source.key_epoch != target_key_epoch {
        return None;
    }
    operations[index + 1..]
        .iter()
        .all(|operation| operation.kind == 4 && operation.key_epoch == target_key_epoch)
        .then_some(source)
}

fn prepare_input_digest(
    context_digest: &[u8; SHA256_LENGTH],
    input: &KelivoAccountRecoveryPrepareInput,
) -> [u8; SHA256_LENGTH] {
    let mut digest = Sha256::new();
    digest.update(b"kelivo.account-recovery.prepare-input.v1\0");
    digest.update(context_digest);
    digest.update(input.kind.to_be_bytes());
    digest.update(input.operation_id);
    digest.update(input.target_auth_generation.to_be_bytes());
    digest.update(input.rekey_operation_id);
    digest.update(input.completion_session_id);
    digest.update(input.completion_session_token_digest);
    digest.finalize().into()
}

unsafe fn read_prepare_input(
    input: *const KelivoAccountRecoveryPrepareInput,
) -> Result<KelivoAccountRecoveryPrepareInput, KelivoStatus> {
    if input.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    let value = unsafe { input.read_unaligned() };
    if value.struct_size != PREPARE_INPUT_STRUCT_SIZE {
        return Err(KelivoStatus::RecoveryPrepareInvalid);
    }
    Ok(value)
}

fn read_capsule(
    input: *const u8,
    input_length: usize,
) -> Result<recovery::RecoveryCapsule, KelivoStatus> {
    let bytes = unsafe { read_input(input, input_length) }?;
    recovery::RecoveryCapsule::from_bytes(bytes).map_err(crate::recovery::recovery_error_status)
}

fn read_optional_capsule(
    input: *const u8,
    input_length: usize,
) -> Result<Option<recovery::RecoveryCapsule>, KelivoStatus> {
    if input_length == 0 {
        if !input.is_null() {
            return Err(KelivoStatus::InvalidArgument);
        }
        return Ok(None);
    }
    read_capsule(input, input_length).map(Some)
}

fn read_fixed<const LENGTH: usize>(
    input: *const u8,
    input_length: usize,
) -> Result<[u8; LENGTH], KelivoStatus> {
    if input_length != LENGTH {
        return Err(KelivoStatus::InvalidArgument);
    }
    let bytes = unsafe { read_input(input, input_length) }?;
    let mut output = [0_u8; LENGTH];
    output.copy_from_slice(bytes);
    Ok(output)
}

unsafe fn reset_bytes(
    output: *mut u8,
    capacity: usize,
    maximum: usize,
    out_length: *mut usize,
) -> Result<(), KelivoStatus> {
    unsafe { write_output(out_length, 0)? };
    if !output.is_null() {
        unsafe { core::ptr::write_bytes(output, 0, capacity.min(maximum)) };
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
unsafe fn reset_proof_outputs(
    out_binding: *mut KelivoAccountRecoveryProofBinding,
    out_nonce_proof: *mut u8,
    out_nonce_proof_capacity: usize,
    out_nonce_proof_length: *mut usize,
    out_trust_signature: *mut u8,
    out_trust_signature_capacity: usize,
    out_trust_signature_length: *mut usize,
) -> Result<(), KelivoStatus> {
    unsafe {
        write_output(out_binding, KelivoAccountRecoveryProofBinding::empty())?;
        reset_bytes(
            out_nonce_proof,
            out_nonce_proof_capacity,
            protocol::ACCOUNT_RECOVERY_NONCE_PROOF_LENGTH,
            out_nonce_proof_length,
        )?;
        reset_bytes(
            out_trust_signature,
            out_trust_signature_capacity,
            TRUST_SIGNATURE_LENGTH,
            out_trust_signature_length,
        )?;
    }
    if out_nonce_proof_capacity < protocol::ACCOUNT_RECOVERY_NONCE_PROOF_LENGTH {
        unsafe {
            write_output(
                out_nonce_proof_length,
                protocol::ACCOUNT_RECOVERY_NONCE_PROOF_LENGTH,
            )?
        };
        return Err(KelivoStatus::OutputBufferTooSmall);
    }
    if out_trust_signature_capacity < TRUST_SIGNATURE_LENGTH {
        unsafe { write_output(out_trust_signature_length, TRUST_SIGNATURE_LENGTH)? };
        return Err(KelivoStatus::OutputBufferTooSmall);
    }
    if out_nonce_proof.is_null() || out_trust_signature.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
unsafe fn reset_replacement_proof_outputs(
    out_binding: *mut KelivoAccountRecoveryReplacementProofBinding,
    out_nonce_proof: *mut u8,
    out_nonce_proof_capacity: usize,
    out_nonce_proof_length: *mut usize,
    out_trust_signature: *mut u8,
    out_trust_signature_capacity: usize,
    out_trust_signature_length: *mut usize,
) -> Result<(), KelivoStatus> {
    unsafe {
        write_output(
            out_binding,
            KelivoAccountRecoveryReplacementProofBinding::empty(),
        )?;
        reset_bytes(
            out_nonce_proof,
            out_nonce_proof_capacity,
            protocol::ACCOUNT_RECOVERY_NONCE_PROOF_LENGTH,
            out_nonce_proof_length,
        )?;
        reset_bytes(
            out_trust_signature,
            out_trust_signature_capacity,
            TRUST_SIGNATURE_LENGTH,
            out_trust_signature_length,
        )?;
    }
    if out_nonce_proof_capacity < protocol::ACCOUNT_RECOVERY_NONCE_PROOF_LENGTH {
        unsafe {
            write_output(
                out_nonce_proof_length,
                protocol::ACCOUNT_RECOVERY_NONCE_PROOF_LENGTH,
            )?
        };
        return Err(KelivoStatus::OutputBufferTooSmall);
    }
    if out_trust_signature_capacity < TRUST_SIGNATURE_LENGTH {
        unsafe { write_output(out_trust_signature_length, TRUST_SIGNATURE_LENGTH)? };
        return Err(KelivoStatus::OutputBufferTooSmall);
    }
    if out_nonce_proof.is_null() || out_trust_signature.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
unsafe fn reset_prepare_outputs(
    out_binding: *mut KelivoAccountRecoveryPrepareBinding,
    out_manifest: *mut u8,
    out_manifest_capacity: usize,
    out_manifest_length: *mut usize,
    out_envelope: *mut u8,
    out_envelope_capacity: usize,
    out_envelope_length: *mut usize,
    out_capsule: *mut u8,
    out_capsule_capacity: usize,
    out_capsule_length: *mut usize,
) -> Result<(), KelivoStatus> {
    unsafe {
        write_output(out_binding, KelivoAccountRecoveryPrepareBinding::empty())?;
        reset_bytes(
            out_manifest,
            out_manifest_capacity,
            PREPARE_MANIFEST_MAX_LENGTH,
            out_manifest_length,
        )?;
        reset_bytes(
            out_envelope,
            out_envelope_capacity,
            crypto::ARK_ENVELOPE_LENGTH,
            out_envelope_length,
        )?;
        reset_bytes(
            out_capsule,
            out_capsule_capacity,
            recovery::RECOVERY_CAPSULE_LENGTH,
            out_capsule_length,
        )?;
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
unsafe fn publish_prepared(
    prepared: &CachedPreparedCommit,
    out_binding: *mut KelivoAccountRecoveryPrepareBinding,
    out_manifest: *mut u8,
    out_manifest_capacity: usize,
    out_manifest_length: *mut usize,
    out_envelope: *mut u8,
    out_envelope_capacity: usize,
    out_envelope_length: *mut usize,
    out_capsule: *mut u8,
    out_capsule_capacity: usize,
    out_capsule_length: *mut usize,
) -> Result<(), KelivoStatus> {
    unsafe {
        write_bytes(
            out_manifest,
            out_manifest_capacity,
            &prepared.manifest,
            out_manifest_length,
        )?;
        write_bytes(
            out_envelope,
            out_envelope_capacity,
            &prepared.envelope,
            out_envelope_length,
        )?;
        match &prepared.capsule {
            Some(value) => {
                write_bytes(out_capsule, out_capsule_capacity, value, out_capsule_length)?
            }
            None => write_output(out_capsule_length, 0)?,
        }
        write_output(out_binding, prepared.binding)
    }
}

#[cfg(test)]
pub(super) fn active_execution_handles() -> usize {
    execution_registry()
        .lock()
        .expect("恢复执行注册表不应中毒")
        .active
        .len()
}

#[cfg(test)]
pub(super) struct TestExecutionBorrow(#[allow(dead_code)] Arc<RecoveryExecution>);

#[cfg(test)]
pub(super) fn borrow_test_execution(handle: u64) -> Result<TestExecutionBorrow, KelivoStatus> {
    execution_for_handle(handle).map(TestExecutionBorrow)
}

#[cfg(test)]
pub(super) fn rebuild_test_execution_for_committed(
    handle: u64,
    expected: KelivoAccountRecoveryStateBinding,
    data_ready: bool,
) -> Result<u64, KelivoStatus> {
    let original = execution_for_handle(handle)?;
    {
        let state = original
            .state
            .lock()
            .map_err(|_| KelivoStatus::InternalState)?;
        let ExecutionState::Prepared(cached) = &*state else {
            return Err(KelivoStatus::RecoveryPrepareInvalid);
        };
        validate_prepared_state_binding(&original, cached, expected)?;
    }
    let source_ark = crate::device_core::ark_for_account_handle(
        original.ark_handle,
        original.challenge.user_id,
        expected.source_key_epoch,
    )?;
    let target_ark = crate::device_core::ark_for_account_handle(
        original.ark_handle,
        original.challenge.user_id,
        expected.target_key_epoch,
    )?;
    let current_trust_public_key = crypto::derive_account_trust_public_key(
        &target_ark,
        crypto::AccountTrustBinding {
            user_id: original.challenge.user_id,
            key_epoch: expected.target_key_epoch,
        },
    )
    .map_err(|_| KelivoStatus::InternalState)?;
    let ark_handle = crate::device_core::register_recovered_ark_keyring(
        original.challenge.user_id,
        Some((expected.source_key_epoch, source_ark)),
        expected.target_key_epoch,
        target_ark,
    )?;
    (|| {
        let mut rng = kelivo_secure_core_protocol::system_rng()
            .map_err(|_| KelivoStatus::RandomSourceFailure)?;
        let recovery_public_key = recovery::RecoveryIdentity::generate(&mut rng)
            .and_then(|identity| identity.public_key())
            .map_err(|_| KelivoStatus::InternalState)?;
        let capsule_version = original
            .challenge
            .recovery_capsule_version
            .checked_add(u32::from(expected.kind == PREPARE_KIND_REPLACEMENT))
            .ok_or(KelivoStatus::RecoveryPrepareInvalid)?;
        let capsule_digest = [0xc7; SHA256_LENGTH];
        let request_digest = [0xc8; SHA256_LENGTH];
        let attempt_id = test_recovery_uuid(0xc1);
        let challenge_frame = test_challenge_frame(
            attempt_id,
            original.challenge.user_id,
            original.challenge.device_id,
            original.challenge.device_key_version,
            original.device_identity.public_keys(),
            expected.membership_generation,
            expected.target_key_epoch,
            expected.membership_manifest_digest,
            recovery_public_key,
            capsule_version,
            capsule_digest,
            if data_ready {
                expected.target_data_generation
            } else {
                expected.source_data_generation
            },
            if data_ready {
                expected.target_key_epoch
            } else {
                expected.source_key_epoch
            },
            if data_ready {
                [0; UUID_LENGTH]
            } else {
                expected.rekey_operation_id
            },
            request_digest,
        );
        let challenge = protocol::VerifiedAccountRecoveryChallenge::parse_and_bind(
            &challenge_frame,
            protocol::AccountRecoveryChallengeExpectation {
                attempt_id,
                user_id: original.challenge.user_id,
                device_id: original.challenge.device_id,
                device_key_version: original.challenge.device_key_version,
                device_public_keys: original.device_identity.public_keys(),
                security_generation: expected.membership_generation,
                key_epoch: expected.target_key_epoch,
                membership_manifest_digest: expected.membership_manifest_digest,
                recovery_public_key_version: 1,
                recovery_public_key,
                recovery_capsule_version: capsule_version,
                recovery_capsule_digest: capsule_digest,
                expires_at_ms: 1_900_000_000_000,
                request_digest,
            },
        )
        .map_err(|_| KelivoStatus::RecoveryChallengeInvalid)?;
        let source_operation = recovery::RecoveryHistoryOperation {
            kind: if expected.kind == PREPARE_KIND_RESUME {
                3
            } else {
                5
            },
            operation_id: expected.rekey_operation_id,
            key_epoch: expected.target_key_epoch,
            authorization_digest: expected.operation_authorization_digest,
        };
        let head_operation = recovery::RecoveryHistoryOperation {
            kind: if expected.kind == PREPARE_KIND_RESUME {
                4
            } else {
                5
            },
            operation_id: if expected.kind == PREPARE_KIND_RESUME {
                test_recovery_uuid(0xc2)
            } else {
                expected.rekey_operation_id
            },
            key_epoch: expected.target_key_epoch,
            authorization_digest: [0; SHA256_LENGTH],
        };
        let operations = if expected.kind == PREPARE_KIND_RESUME {
            vec![source_operation, head_operation]
        } else {
            vec![head_operation]
        };
        let history_head = recovery::VerifiedRecoveryHistoryHead {
            user_id: original.challenge.user_id,
            security_generation: expected.membership_generation,
            key_epoch: expected.target_key_epoch,
            digest: expected.membership_manifest_digest,
            current_trust_public_key,
            recovery_public_key_version: 1,
            recovery_public_key,
            recovery_capsule_version: capsule_version,
            recovery_capsule_digest: capsule_digest,
            operation_kind: head_operation.kind,
            operation_id: head_operation.operation_id,
            issuer_device_id: original.challenge.device_id,
            subject_device_id: original.challenge.device_id,
            operation_authorization_digest: head_operation.authorization_digest,
            members: vec![recovery::RecoveryHistoryMember {
                device_id: original.challenge.device_id,
                key_version: original.challenge.device_key_version,
                auth_generation: original.target_auth_generation,
                signing_public_key: original.device_identity.public_keys().signing,
                key_agreement_public_key: original.device_identity.public_keys().key_agreement,
            }],
            operations,
            manifest: Vec::new(),
        };
        register_execution(RecoveryExecution {
            device_identity: Arc::clone(&original.device_identity),
            ark_handle,
            target_auth_generation: original.target_auth_generation,
            replacement_only: false,
            verified_challenge: VerifiedRecoveryChallenge::Initial(Box::new(challenge)),
            challenge: RecoveryExecutionChallenge::initial(&challenge),
            history_head,
            source_operation_authorization_digest: if data_ready {
                [0; SHA256_LENGTH]
            } else {
                expected.operation_authorization_digest
            },
            context_digest: [0xc9; SHA256_LENGTH],
            state: Mutex::new(ExecutionState::Ready),
        })
    })()
}

#[cfg(test)]
fn test_recovery_uuid(seed: u8) -> [u8; UUID_LENGTH] {
    let mut value = [seed; UUID_LENGTH];
    value[6] = (value[6] & 0x0f) | 0x40;
    value[8] = (value[8] & 0x3f) | 0x80;
    value
}

#[cfg(test)]
#[allow(clippy::too_many_arguments)]
fn test_challenge_frame(
    attempt_id: [u8; UUID_LENGTH],
    user_id: crypto::UserId,
    device_id: crypto::DeviceId,
    device_key_version: u32,
    device_public_keys: crypto::DevicePublicKeys,
    security_generation: u32,
    key_epoch: u32,
    membership_manifest_digest: [u8; SHA256_LENGTH],
    recovery_public_key: recovery::RecoveryPublicKey,
    recovery_capsule_version: u32,
    recovery_capsule_digest: [u8; SHA256_LENGTH],
    source_data_generation: u32,
    source_data_key_epoch: u32,
    source_rekey_operation_id: [u8; UUID_LENGTH],
    request_digest: [u8; SHA256_LENGTH],
) -> [u8; protocol::ACCOUNT_RECOVERY_CHALLENGE_LENGTH] {
    let mut frame = [0_u8; protocol::ACCOUNT_RECOVERY_CHALLENGE_LENGTH];
    frame[..8].copy_from_slice(b"KELIVORC");
    frame[8..12].copy_from_slice(&protocol::ACCOUNT_RECOVERY_PROTOCOL_VERSION.to_be_bytes());
    frame[12..14].copy_from_slice(&0x20_u16.to_be_bytes());
    frame[14..16].copy_from_slice(&1_u16.to_be_bytes());
    frame[16..18].copy_from_slice(&3_u16.to_be_bytes());
    frame[20..36].copy_from_slice(&attempt_id);
    frame[36..52].copy_from_slice(user_id.as_bytes());
    frame[52..68].copy_from_slice(device_id.as_bytes());
    frame[68..72].copy_from_slice(&device_key_version.to_be_bytes());
    frame[72..104].copy_from_slice(device_public_keys.signing.as_bytes());
    frame[104..136].copy_from_slice(device_public_keys.key_agreement.as_bytes());
    frame[136..140].copy_from_slice(&security_generation.to_be_bytes());
    frame[140..144].copy_from_slice(&key_epoch.to_be_bytes());
    frame[144..176].copy_from_slice(&membership_manifest_digest);
    frame[176..180].copy_from_slice(&1_u32.to_be_bytes());
    frame[180..212].copy_from_slice(recovery_public_key.as_bytes());
    frame[212..216].copy_from_slice(&recovery_capsule_version.to_be_bytes());
    frame[216..248].copy_from_slice(&recovery_capsule_digest);
    frame[248] = u8::from(source_rekey_operation_id != [0; UUID_LENGTH]);
    frame[252..256].copy_from_slice(&source_data_generation.to_be_bytes());
    frame[256..260].copy_from_slice(&source_data_key_epoch.to_be_bytes());
    frame[260..276].copy_from_slice(&source_rekey_operation_id);
    frame[276..284].copy_from_slice(&1_900_000_000_000_u64.to_be_bytes());
    frame[284..316].copy_from_slice(&request_digest);
    frame
}

#[cfg(test)]
mod tests {
    use super::*;

    fn operation(
        seed: u8,
        kind: u32,
        key_epoch: u32,
        authorization_digest: [u8; SHA256_LENGTH],
    ) -> recovery::RecoveryHistoryOperation {
        let mut operation_id = [seed; UUID_LENGTH];
        operation_id[6] = (operation_id[6] & 0x0f) | 0x40;
        operation_id[8] = (operation_id[8] & 0x3f) | 0x80;
        recovery::RecoveryHistoryOperation {
            kind,
            operation_id,
            key_epoch,
            authorization_digest,
        }
    }

    #[test]
    fn source_rekey_accepts_direct_ready_replacement() {
        let replacement = operation(0x31, 5, 3, [0; SHA256_LENGTH]);
        let operations = [replacement];

        assert_eq!(
            source_rekey_operation(&operations, replacement.operation_id, 3),
            Some(&replacement)
        );
    }

    #[test]
    fn source_rekey_accepts_all_consecutive_resume_takeovers() {
        let source = operation(0x41, 3, 2, [0x51; SHA256_LENGTH]);
        let operations = [
            operation(0x40, 1, 1, [0; SHA256_LENGTH]),
            source,
            operation(0x42, 4, 2, [0; SHA256_LENGTH]),
            operation(0x43, 4, 2, [0; SHA256_LENGTH]),
        ];

        assert_eq!(
            source_rekey_operation(&operations, source.operation_id, 2),
            Some(&source)
        );
    }

    #[test]
    fn source_rekey_rejects_non_resume_suffix_or_wrong_epoch() {
        let source = operation(0x61, 3, 2, [0x71; SHA256_LENGTH]);
        let interrupted = [
            source,
            operation(0x62, 4, 2, [0; SHA256_LENGTH]),
            operation(0x63, 2, 2, [0; SHA256_LENGTH]),
        ];

        assert!(source_rekey_operation(&interrupted, source.operation_id, 2).is_none());
        assert!(source_rekey_operation(&interrupted[..1], source.operation_id, 3).is_none());
    }

    #[test]
    fn replacement_completion_requires_latest_resume_head_and_exact_device() {
        let mut rng = kelivo_secure_core_protocol::system_rng().expect("测试随机源应可用");
        let identity = crypto::DeviceIdentity::generate(&mut rng).expect("测试设备身份应有效");
        let user_id = crypto::UserId::new(test_recovery_uuid(0x71)).expect("测试账户应有效");
        let device_id = crypto::DeviceId::new(test_recovery_uuid(0x72)).expect("测试设备应有效");
        let source = operation(0x73, 3, 2, [0x74; SHA256_LENGTH]);
        let first_resume = operation(0x75, 4, 2, [0; SHA256_LENGTH]);
        let latest_resume = operation(0x76, 4, 2, [0; SHA256_LENGTH]);
        let membership_digest = [0x77; SHA256_LENGTH];
        let recovery_identity =
            recovery::RecoveryIdentity::from_private_bytes([0x78; 32]).expect("测试恢复身份应有效");
        let recovery_public_key = recovery_identity.public_key().expect("测试恢复公钥应派生");
        let ark = crypto::AccountRootKey::from_bytes([0x79; 32]);
        let current_trust_public_key = crypto::derive_account_trust_public_key(
            &ark,
            crypto::AccountTrustBinding {
                user_id,
                key_epoch: 2,
            },
        )
        .expect("测试信任公钥应派生");
        let history = recovery::VerifiedRecoveryHistoryHead {
            user_id,
            security_generation: 4,
            key_epoch: 2,
            digest: membership_digest,
            current_trust_public_key,
            recovery_public_key_version: 1,
            recovery_public_key,
            recovery_capsule_version: 2,
            recovery_capsule_digest: [0x7a; SHA256_LENGTH],
            operation_kind: 4,
            operation_id: latest_resume.operation_id,
            issuer_device_id: device_id,
            subject_device_id: device_id,
            operation_authorization_digest: [0; SHA256_LENGTH],
            members: vec![recovery::RecoveryHistoryMember {
                device_id,
                key_version: 1,
                auth_generation: 2,
                signing_public_key: identity.public_keys().signing,
                key_agreement_public_key: identity.public_keys().key_agreement,
            }],
            operations: vec![source, first_resume, latest_resume],
            manifest: Vec::new(),
        };
        let mut frame = [0_u8; crypto::DATA_REKEY_COMPLETION_PROOF_FRAME_LENGTH];
        frame[..32].copy_from_slice(b"kelivo-data-rekey-completion-v2\0");
        frame[32..48].copy_from_slice(&source.operation_id);
        frame[48..64].copy_from_slice(user_id.as_bytes());
        frame[64..80].copy_from_slice(device_id.as_bytes());
        frame[80..84].copy_from_slice(&8_u32.to_be_bytes());
        frame[84..88].copy_from_slice(&9_u32.to_be_bytes());
        frame[88..92].copy_from_slice(&1_u32.to_be_bytes());
        frame[92..96].copy_from_slice(&2_u32.to_be_bytes());
        frame[194..198].copy_from_slice(&4_u32.to_be_bytes());
        frame[198..230].copy_from_slice(&membership_digest);
        let signature = identity
            .sign_data_rekey_completion_proof(&frame)
            .expect("测试完成证明应签名");
        let completion = crypto::verify_and_bind_data_rekey_completion_proof(
            &identity.public_keys().signing,
            &frame,
            signature.as_bytes(),
        )
        .expect("测试完成证明应验证");

        assert_eq!(
            validate_replacement_completion_binding(
                &history, &identity, device_id, 1, 2, completion,
            ),
            Ok(source.authorization_digest)
        );

        let mut stale_head = history.clone();
        stale_head.digest[0] ^= 1;
        assert_eq!(
            validate_replacement_completion_binding(
                &stale_head,
                &identity,
                device_id,
                1,
                2,
                completion,
            ),
            Err(KelivoStatus::RecoveryChallengeInvalid)
        );
        assert_eq!(
            validate_replacement_completion_binding(
                &history, &identity, device_id, 1, 3, completion,
            ),
            Err(KelivoStatus::RecoveryChallengeInvalid)
        );
    }
}
