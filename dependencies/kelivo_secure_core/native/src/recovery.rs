use std::{
    collections::HashMap,
    sync::{Arc, Mutex, OnceLock},
};

use kelivo_secure_core_protocol::{
    self as protocol, device_crypto::UserId, recovery_crypto as recovery,
};

use crate::{
    INVALID_KEY_HANDLE, KelivoStatus, RECOVERY_HANDLE_TAG, handle_has_tag, issue_typed_handle,
    read_input, write_bytes, write_output,
};

pub(super) const RECOVERY_PUBLIC_KEY_LENGTH: usize = recovery::RECOVERY_PUBLIC_KEY_LENGTH;
pub(super) const RECOVERY_CAPSULE_LENGTH: usize = recovery::RECOVERY_CAPSULE_LENGTH;
pub(super) const RECOVERY_MEDIA_LENGTH: usize = recovery::RECOVERY_MEDIA_LENGTH;
pub(super) const RECOVERY_HISTORY_MAX_BYTES: usize = recovery::RECOVERY_HISTORY_MAX_BYTES;
pub(super) const RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH: usize =
    recovery::RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH;
pub(super) const RECOVERY_CAPSULE_BINDING_STRUCT_SIZE: u32 = 28;
pub(super) const RECOVERY_MEDIA_EXPORT_AUTHORITY_STRUCT_SIZE: u32 = 168;

const UUID_LENGTH: usize = 16;
const MAX_ACTIVE_RECOVERY_HANDLES: usize = 64;
const RECOVERY_USER_FLOW_AVAILABLE: bool =
    cfg!(any(target_os = "android", target_os = "ios", test));

pub(super) fn require_recovery_user_flow() -> Result<(), KelivoStatus> {
    if RECOVERY_USER_FLOW_AVAILABLE {
        Ok(())
    } else {
        Err(KelivoStatus::UnsupportedPlatform)
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct KelivoRecoveryCapsuleBinding {
    pub struct_size: u32,
    pub user_id: [u8; UUID_LENGTH],
    pub key_epoch: u32,
    pub capsule_version: u32,
}

impl KelivoRecoveryCapsuleBinding {
    const fn empty() -> Self {
        Self {
            struct_size: 0,
            user_id: [0; UUID_LENGTH],
            key_epoch: 0,
            capsule_version: 0,
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct KelivoRecoveryMediaExportAuthority {
    pub struct_size: u32,
    pub initial_capsule: [u8; RECOVERY_CAPSULE_LENGTH],
    pub local_epoch_one_ark_handle: u64,
}

impl Default for KelivoRecoveryMediaExportAuthority {
    fn default() -> Self {
        Self {
            struct_size: 0,
            initial_capsule: [0; RECOVERY_CAPSULE_LENGTH],
            local_epoch_one_ark_handle: INVALID_KEY_HANDLE,
        }
    }
}

const _: () = {
    assert!(
        core::mem::size_of::<KelivoRecoveryCapsuleBinding>()
            == RECOVERY_CAPSULE_BINDING_STRUCT_SIZE as usize
    );
    assert!(
        core::mem::size_of::<KelivoRecoveryMediaExportAuthority>()
            == RECOVERY_MEDIA_EXPORT_AUTHORITY_STRUCT_SIZE as usize
    );
};

struct BoundRecoveryIdentity {
    user_id: UserId,
    recovery_public_key_version: u32,
    identity: recovery::RecoveryIdentity,
}

struct RecoveryRegistry {
    active: HashMap<u64, Arc<BoundRecoveryIdentity>>,
    next_sequence: u64,
}

impl Default for RecoveryRegistry {
    fn default() -> Self {
        Self {
            active: HashMap::new(),
            next_sequence: 1,
        }
    }
}

fn recovery_registry() -> &'static Mutex<RecoveryRegistry> {
    static REGISTRY: OnceLock<Mutex<RecoveryRegistry>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(RecoveryRegistry::default()))
}

fn register_recovery(value: BoundRecoveryIdentity) -> Result<u64, KelivoStatus> {
    let mut registry = recovery_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    if registry.active.len() >= MAX_ACTIVE_RECOVERY_HANDLES {
        return Err(KelivoStatus::TooManyActiveHandles);
    }
    let handle = issue_typed_handle(RECOVERY_HANDLE_TAG, &mut registry.next_sequence)?;
    let replaced = registry.active.insert(handle, Arc::new(value));
    debug_assert!(replaced.is_none());
    Ok(handle)
}

fn recovery_for_handle(handle: u64) -> Result<Arc<BoundRecoveryIdentity>, KelivoStatus> {
    if !handle_has_tag(handle, RECOVERY_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidRecoveryHandle);
    }
    let registry = recovery_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    registry
        .active
        .get(&handle)
        .map(Arc::clone)
        .ok_or(KelivoStatus::InvalidRecoveryHandle)
}

fn close_recovery(handle: u64) -> Result<(), KelivoStatus> {
    if !handle_has_tag(handle, RECOVERY_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidRecoveryHandle);
    }
    let mut registry = recovery_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    let entry = registry
        .active
        .get(&handle)
        .ok_or(KelivoStatus::InvalidRecoveryHandle)?;
    if Arc::strong_count(entry) != 1 {
        return Err(KelivoStatus::SlotInUse);
    }
    let removed = registry
        .active
        .remove(&handle)
        .ok_or(KelivoStatus::InternalState)?;
    drop(removed);
    Ok(())
}

fn read_user_id(input: *const u8, input_length: usize) -> Result<UserId, KelivoStatus> {
    if input_length != UUID_LENGTH {
        return Err(KelivoStatus::InvalidAccountId);
    }
    let bytes = unsafe { read_input(input, input_length) }?;
    UserId::new(copy_array(bytes)).map_err(|_| KelivoStatus::InvalidAccountId)
}

fn read_origin_digest(
    input: *const u8,
    input_length: usize,
) -> Result<[u8; RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH], KelivoStatus> {
    if input_length != RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH {
        return Err(KelivoStatus::InvalidArgument);
    }
    let bytes = unsafe { read_input(input, input_length) }?;
    Ok(copy_array(bytes))
}

pub(super) fn recovery_error_status(error: recovery::RecoveryCryptoError) -> KelivoStatus {
    use recovery::RecoveryCryptoError as Error;
    match error {
        Error::InvalidUserId | Error::InvalidPositiveVersion => KelivoStatus::InvalidArgument,
        Error::InvalidRecoveryPublicKey
        | Error::InvalidCapsuleLength { .. }
        | Error::InvalidCapsuleMagic
        | Error::UnsupportedCapsuleVersion(_)
        | Error::UnsupportedCapsuleSuite(_)
        | Error::UnsupportedCapsuleReserved(_) => KelivoStatus::RecoveryCapsuleInvalid,
        Error::InvalidRecoveryPrivateKey
        | Error::RecoveryKeyMismatch
        | Error::CapsuleBindingMismatch
        | Error::InitialCapsuleArkMismatch
        | Error::CapsuleOpenFailed => KelivoStatus::RecoveryCapsuleAuthenticationFailed,
        Error::InitialCapsuleMismatch => KelivoStatus::RecoveryCapsuleInvalid,
        Error::CapsuleSealFailed => KelivoStatus::InternalState,
        Error::RandomnessUnavailable => KelivoStatus::RandomSourceFailure,
        Error::InvalidPassphraseUtf8 | Error::PassphraseTooShort | Error::PassphraseTooLong => {
            KelivoStatus::RecoveryPassphraseInvalid
        }
        Error::InvalidMediaLength { .. }
        | Error::InvalidMediaMagic
        | Error::UnsupportedMediaVersion(_)
        | Error::UnsupportedMediaSuite(_)
        | Error::UnsupportedMediaKdfProfile(_)
        | Error::UnsupportedMediaFlags(_)
        | Error::InvalidMediaDeclaredLength(_)
        | Error::InvalidMediaPlaintextLength(_) => KelivoStatus::RecoveryMediaInvalid,
        Error::MediaOriginMismatch => KelivoStatus::RecoveryOriginMismatch,
        Error::MediaAuthenticationFailed => KelivoStatus::RecoveryMediaAuthenticationFailed,
        Error::InvalidGenesis
        | Error::GenesisDigestMismatch
        | Error::GenesisTrustRootMismatch
        | Error::GenesisCapsuleDigestMismatch
        | Error::GenesisSignatureInvalid => KelivoStatus::RecoveryGenesisInvalid,
        Error::InvalidMembershipHistory
        | Error::MembershipHistoryAnchorMismatch
        | Error::MembershipHistoryTransitionInvalid
        | Error::MembershipHistoryHeadMismatch => KelivoStatus::RecoveryHistoryInvalid,
        Error::MembershipHistorySignatureInvalid => {
            KelivoStatus::RecoveryHistoryAuthenticationFailed
        }
        Error::MediaKdfFailed | Error::MediaSealFailed => KelivoStatus::InternalState,
    }
}

unsafe fn read_media_export_authority(
    input: *const KelivoRecoveryMediaExportAuthority,
) -> Result<KelivoRecoveryMediaExportAuthority, KelivoStatus> {
    if input.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    let value = unsafe { input.read_unaligned() };
    if value.struct_size != RECOVERY_MEDIA_EXPORT_AUTHORITY_STRUCT_SIZE {
        return Err(KelivoStatus::InvalidArgument);
    }
    Ok(value)
}

unsafe fn reset_fixed_bytes<const LENGTH: usize>(
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> Result<(), KelivoStatus> {
    unsafe { write_output(output_length, 0)? };
    if !output.is_null() {
        unsafe {
            core::ptr::write_bytes(output, 0, output_capacity.min(LENGTH));
        }
    }
    Ok(())
}

unsafe fn reset_identity_outputs(
    out_handle: *mut u64,
    out_public_key: *mut u8,
    out_public_key_capacity: usize,
    out_public_key_length: *mut usize,
) -> Result<(), KelivoStatus> {
    unsafe {
        write_output(out_handle, INVALID_KEY_HANDLE)?;
        reset_fixed_bytes::<RECOVERY_PUBLIC_KEY_LENGTH>(
            out_public_key,
            out_public_key_capacity,
            out_public_key_length,
        )
    }
}

/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出指针必须指向对应容量的可写内存。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_recovery_identity_generate(
    user_id: *const u8,
    user_id_length: usize,
    recovery_public_key_version: u32,
    out_handle: *mut u64,
    out_public_key: *mut u8,
    out_public_key_capacity: usize,
    out_public_key_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        reset_identity_outputs(
            out_handle,
            out_public_key,
            out_public_key_capacity,
            out_public_key_length,
        )
    } {
        return status.code();
    }
    if let Err(status) = unsafe {
        crate::device_core::prepare_fixed_output(
            out_public_key,
            out_public_key_capacity,
            out_public_key_length,
            RECOVERY_PUBLIC_KEY_LENGTH,
        )
    } {
        return status.code();
    }
    if let Err(status) = require_recovery_user_flow() {
        return status.code();
    }
    if recovery_public_key_version == 0 {
        return KelivoStatus::InvalidArgument.code();
    }
    let user_id = match read_user_id(user_id, user_id_length) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let mut rng = match protocol::system_rng() {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let identity = match recovery::RecoveryIdentity::generate(&mut rng) {
        Ok(value) => value,
        Err(error) => return recovery_error_status(error).code(),
    };
    let public_key = match identity.public_key() {
        Ok(value) => value,
        Err(error) => return recovery_error_status(error).code(),
    };
    let handle = match register_recovery(BoundRecoveryIdentity {
        user_id,
        recovery_public_key_version,
        identity,
    }) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    if let Err(status) = unsafe {
        write_bytes(
            out_public_key,
            out_public_key_capacity,
            public_key.as_bytes(),
            out_public_key_length,
        )
    } {
        let _ = close_recovery(handle);
        return status.code();
    }
    match unsafe { write_output(out_handle, handle) } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => {
            let _ = close_recovery(handle);
            status.code()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_recovery_handle_close(handle: u64) -> i32 {
    match close_recovery(handle) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出指针必须指向对应容量的可写内存。
#[unsafe(no_mangle)]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn kelivo_recovery_capsule_seal(
    ark_handle: u64,
    user_id: *const u8,
    user_id_length: usize,
    key_epoch: u32,
    recovery_public_key_version: u32,
    capsule_version: u32,
    recovery_public_key: *const u8,
    recovery_public_key_length: usize,
    out_capsule: *mut u8,
    out_capsule_capacity: usize,
    out_capsule_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        reset_fixed_bytes::<RECOVERY_CAPSULE_LENGTH>(
            out_capsule,
            out_capsule_capacity,
            out_capsule_length,
        )
    } {
        return status.code();
    }
    if let Err(status) = unsafe {
        crate::device_core::prepare_fixed_output(
            out_capsule,
            out_capsule_capacity,
            out_capsule_length,
            RECOVERY_CAPSULE_LENGTH,
        )
    } {
        return status.code();
    }
    let user_id = match read_user_id(user_id, user_id_length) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    if recovery_public_key_length != RECOVERY_PUBLIC_KEY_LENGTH {
        return KelivoStatus::RecoveryCapsuleInvalid.code();
    }
    let recovery_public_key =
        match unsafe { read_input(recovery_public_key, recovery_public_key_length) } {
            Ok(value) => match recovery::RecoveryPublicKey::from_bytes(copy_array(value)) {
                Ok(value) => value,
                Err(error) => return recovery_error_status(error).code(),
            },
            Err(status) => return status.code(),
        };
    let ark = match crate::device_core::ark_for_account_handle(ark_handle, user_id, key_epoch) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let mut rng = match protocol::system_rng() {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let capsule = match recovery::seal_recovery_capsule(
        &mut rng,
        &ark,
        user_id,
        key_epoch,
        recovery_public_key_version,
        capsule_version,
        recovery_public_key,
    ) {
        Ok(value) => value,
        Err(error) => return recovery_error_status(error).code(),
    };
    match unsafe {
        write_bytes(
            out_capsule,
            out_capsule_capacity,
            capsule.as_bytes(),
            out_capsule_length,
        )
    } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出指针必须指向对应容量的可写内存。
#[unsafe(no_mangle)]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn kelivo_recovery_media_export(
    recovery_handle: u64,
    authority: *const KelivoRecoveryMediaExportAuthority,
    genesis: *const u8,
    genesis_length: usize,
    passphrase: *const u8,
    passphrase_length: usize,
    service_origin_sha256: *const u8,
    service_origin_sha256_length: usize,
    out_media: *mut u8,
    out_media_capacity: usize,
    out_media_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        reset_fixed_bytes::<RECOVERY_MEDIA_LENGTH>(out_media, out_media_capacity, out_media_length)
    } {
        return status.code();
    }
    if let Err(status) = unsafe {
        crate::device_core::prepare_fixed_output(
            out_media,
            out_media_capacity,
            out_media_length,
            RECOVERY_MEDIA_LENGTH,
        )
    } {
        return status.code();
    }
    if let Err(status) = require_recovery_user_flow() {
        return status.code();
    }
    let bound = match recovery_for_handle(recovery_handle) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let authority = match unsafe { read_media_export_authority(authority) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let initial_capsule = match recovery::RecoveryCapsule::from_bytes(&authority.initial_capsule) {
        Ok(value) => value,
        Err(error) => return recovery_error_status(error).code(),
    };
    let local_epoch_one_ark = match crate::device_core::ark_for_account_handle(
        authority.local_epoch_one_ark_handle,
        bound.user_id,
        1,
    ) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let genesis = match unsafe { read_input(genesis, genesis_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let passphrase = match unsafe { read_input(passphrase, passphrase_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let origin = match read_origin_digest(service_origin_sha256, service_origin_sha256_length) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let mut rng = match protocol::system_rng() {
        Ok(value) => value,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let media = match recovery::seal_recovery_media(
        &mut rng,
        &bound.identity,
        bound.user_id,
        bound.recovery_public_key_version,
        recovery::RecoveryMediaExportAuthority::new(
            &local_epoch_one_ark,
            &initial_capsule,
            genesis,
        ),
        passphrase,
        &origin,
    ) {
        Ok(value) => value,
        Err(error) => return recovery_error_status(error).code(),
    };
    match unsafe {
        write_bytes(
            out_media,
            out_media_capacity,
            media.as_bytes(),
            out_media_length,
        )
    } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出指针必须指向对应容量的可写内存。
#[unsafe(no_mangle)]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn kelivo_recovery_media_import_history_verify_and_capsule_open(
    media: *const u8,
    media_length: usize,
    passphrase: *const u8,
    passphrase_length: usize,
    expected_service_origin_sha256: *const u8,
    expected_service_origin_sha256_length: usize,
    membership_history: *const u8,
    membership_history_length: usize,
    source_capsule: *const u8,
    source_capsule_length: usize,
    current_capsule: *const u8,
    current_capsule_length: usize,
    out_binding: *mut KelivoRecoveryCapsuleBinding,
    out_ark_handle: *mut u64,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_binding, KelivoRecoveryCapsuleBinding::empty()) }
    {
        return status.code();
    }
    if let Err(status) = unsafe { write_output(out_ark_handle, INVALID_KEY_HANDLE) } {
        return status.code();
    }
    if let Err(status) = require_recovery_user_flow() {
        return status.code();
    }
    let media = match unsafe { read_input(media, media_length) } {
        Ok(value) => match recovery::RecoveryMedia::from_bytes(value) {
            Ok(value) => value,
            Err(error) => return recovery_error_status(error).code(),
        },
        Err(status) => return status.code(),
    };
    let passphrase = match unsafe { read_input(passphrase, passphrase_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let origin = match read_origin_digest(
        expected_service_origin_sha256,
        expected_service_origin_sha256_length,
    ) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let source_capsule = if source_capsule_length == 0 {
        if !source_capsule.is_null() {
            return KelivoStatus::InvalidArgument.code();
        }
        None
    } else {
        match unsafe { read_input(source_capsule, source_capsule_length) } {
            Ok(value) => match recovery::RecoveryCapsule::from_bytes(value) {
                Ok(value) => Some(value),
                Err(error) => return recovery_error_status(error).code(),
            },
            Err(status) => return status.code(),
        }
    };
    let current_capsule = match unsafe { read_input(current_capsule, current_capsule_length) } {
        Ok(value) => match recovery::RecoveryCapsule::from_bytes(value) {
            Ok(value) => value,
            Err(error) => return recovery_error_status(error).code(),
        },
        Err(status) => return status.code(),
    };
    if membership_history_length == 0 || membership_history_length > RECOVERY_HISTORY_MAX_BYTES {
        return KelivoStatus::RecoveryHistoryInvalid.code();
    }
    let membership_history =
        match unsafe { read_input(membership_history, membership_history_length) } {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let imported = match recovery::open_recovery_media(&media, passphrase, &origin) {
        Ok(value) => value,
        Err(error) => return recovery_error_status(error).code(),
    };
    let opened = match recovery::verify_recovery_history_and_open_capsules(
        &imported.identity,
        imported.user_id,
        imported.recovery_public_key_version,
        &imported.genesis,
        membership_history,
        source_capsule.as_ref(),
        &current_capsule,
    ) {
        Ok(value) => value,
        Err(error) => return recovery_error_status(error).code(),
    };
    let binding = KelivoRecoveryCapsuleBinding {
        struct_size: RECOVERY_CAPSULE_BINDING_STRUCT_SIZE,
        user_id: *opened.current.user_id.as_bytes(),
        key_epoch: opened.current.key_epoch,
        capsule_version: opened.current.capsule_version,
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
    if let Err(status) = unsafe { write_output(out_binding, binding) } {
        let _ = crate::device_core::close_ark(ark_handle);
        return status.code();
    }
    match unsafe { write_output(out_ark_handle, ark_handle) } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => {
            let _ = crate::device_core::close_ark(ark_handle);
            status.code()
        }
    }
}

fn copy_array<const LENGTH: usize>(bytes: &[u8]) -> [u8; LENGTH] {
    let mut output = [0_u8; LENGTH];
    output.copy_from_slice(bytes);
    output
}

#[cfg(test)]
pub(super) fn active_recovery_handles() -> usize {
    recovery_registry()
        .lock()
        .expect("恢复注册表不应中毒")
        .active
        .len()
}

#[cfg(test)]
pub(super) struct TestRecoveryBorrow(#[allow(dead_code)] Arc<BoundRecoveryIdentity>);

#[cfg(test)]
pub(super) fn borrow_test_recovery(handle: u64) -> Result<TestRecoveryBorrow, KelivoStatus> {
    recovery_for_handle(handle).map(TestRecoveryBorrow)
}
