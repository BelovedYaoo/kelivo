use std::{
    collections::{HashMap, hash_map::Entry},
    sync::{Arc, Mutex, OnceLock},
};

use kelivo_secure_core_protocol::{
    account_recovery as protocol,
    device_crypto::{self as crypto, AccountTrustBinding},
    recovery_crypto as recovery,
};
use sha2::{Digest, Sha256};

use crate::{
    HANDLE_RESERVED_MASK, HANDLE_TAG_MASK, KelivoStatus, read_input, write_bytes, write_output,
};

const UUID_LENGTH: usize = 16;
const SHA256_LENGTH: usize = 32;
const TRUST_SIGNATURE_LENGTH: usize = 64;
const RECOVERY_EXECUTION_SUBTYPE: u64 = 1_u64 << 59;
const RECOVERY_EXECUTION_HANDLE_TAG: u64 = crate::RECOVERY_HANDLE_TAG | RECOVERY_EXECUTION_SUBTYPE;
const RECOVERY_EXECUTION_SEQUENCE_MASK: u64 = RECOVERY_EXECUTION_SUBTYPE - 1;
const MAX_ACTIVE_RECOVERY_EXECUTIONS: usize = 64;
const PROOF_BINDING_STRUCT_SIZE: u32 = 72;
const PREPARE_INPUT_STRUCT_SIZE: u32 = 92;
const PREPARE_BINDING_STRUCT_SIZE: u32 = 96;
const PREPARE_KIND_RESUME: u32 = 1;
const PREPARE_KIND_REPLACEMENT: u32 = 2;
const PREPARE_MANIFEST_MAX_LENGTH: usize = 228 + 256 * 88 + 128;

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct KelivoAccountRecoveryProofBinding {
    pub struct_size: u32,
    pub data_phase: u32,
    pub execution_handle: u64,
    pub ark_handle: u64,
    pub user_id: [u8; UUID_LENGTH],
    pub device_id: [u8; UUID_LENGTH],
    pub security_generation: u32,
    pub key_epoch: u32,
    pub device_key_version: u32,
    pub recovery_capsule_version: u32,
}

impl KelivoAccountRecoveryProofBinding {
    const fn empty() -> Self {
        Self {
            struct_size: 0,
            data_phase: 0,
            execution_handle: 0,
            ark_handle: 0,
            user_id: [0; UUID_LENGTH],
            device_id: [0; UUID_LENGTH],
            security_generation: 0,
            key_epoch: 0,
            device_key_version: 0,
            recovery_capsule_version: 0,
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

const _: () = {
    assert!(size_of::<KelivoAccountRecoveryProofBinding>() == PROOF_BINDING_STRUCT_SIZE as usize);
    assert!(size_of::<KelivoAccountRecoveryPrepareInput>() == PREPARE_INPUT_STRUCT_SIZE as usize);
    assert!(
        size_of::<KelivoAccountRecoveryPrepareBinding>() == PREPARE_BINDING_STRUCT_SIZE as usize
    );
};

#[derive(Clone)]
struct CachedPreparedCommit {
    input_digest: [u8; SHA256_LENGTH],
    binding: KelivoAccountRecoveryPrepareBinding,
    manifest: Vec<u8>,
    envelope: [u8; crypto::ARK_ENVELOPE_LENGTH],
    capsule: Option<[u8; recovery::RECOVERY_CAPSULE_LENGTH]>,
}

enum ExecutionState {
    Ready,
    Prepared(Box<CachedPreparedCommit>),
    Invalidated,
}

struct RecoveryExecution {
    device_identity: Arc<crypto::DeviceIdentity>,
    ark_handle: u64,
    target_auth_generation: u32,
    challenge: protocol::VerifiedAccountRecoveryChallenge,
    history_head: recovery::VerifiedRecoveryHistoryHead,
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
    let execution = RecoveryExecution {
        device_identity,
        ark_handle,
        target_auth_generation: expected_device_auth_generation,
        challenge,
        history_head: opened.history_head,
        context_digest,
        state: Mutex::new(ExecutionState::Ready),
    };
    let execution_handle = match register_execution(execution) {
        Ok(value) => value,
        Err(status) => {
            let _ = crate::device_core::close_ark(ark_handle);
            return status.code();
        }
    };
    let binding = KelivoAccountRecoveryProofBinding {
        struct_size: PROOF_BINDING_STRUCT_SIZE,
        data_phase: match challenge.data_phase {
            protocol::AccountRecoveryDataPhase::Ready => 1,
            protocol::AccountRecoveryDataPhase::RekeyPending => 2,
        },
        execution_handle,
        ark_handle,
        user_id: *challenge.user_id.as_bytes(),
        device_id: *challenge.device_id.as_bytes(),
        security_generation: challenge.security_generation,
        key_epoch: challenge.key_epoch,
        device_key_version: challenge.device_key_version,
        recovery_capsule_version: challenge.recovery_capsule_version,
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
                let prepared = match protocol::prepare_account_recovery_commit(
                    &mut rng,
                    &current_ark,
                    &execution.device_identity,
                    &execution.challenge,
                    &execution.history_head,
                    protocol_input,
                ) {
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
                let cached = CachedPreparedCommit {
                    input_digest,
                    binding,
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
