#![forbid(unsafe_op_in_unsafe_fn)]

use core::{ffi::c_void, mem::size_of, slice};
use std::{
    collections::HashMap,
    sync::{Arc, Mutex, OnceLock},
};
use zeroize::Zeroizing;

mod attachment;
mod database;
mod device_core;
mod opaque_client;
mod record;
mod recovery;

pub use attachment::{
    kelivo_attachment_chunk_open, kelivo_attachment_chunk_seal,
    kelivo_attachment_data_key_generate, kelivo_attachment_data_key_handle_close,
    kelivo_attachment_data_key_unwrap, kelivo_attachment_data_key_wrap,
};

pub use device_core::{
    KelivoDeviceStateBinding, kelivo_account_record_id_derive,
    kelivo_account_root_key_envelope_open, kelivo_account_root_key_envelope_seal,
    kelivo_account_root_key_generate, kelivo_account_root_key_handle_close,
    kelivo_account_root_keyring_add_epoch, kelivo_account_root_keyring_prune_epoch,
    kelivo_account_trust_payload_sign, kelivo_account_trust_payload_verify,
    kelivo_account_trust_public_key_derive, kelivo_device_identity_generate,
    kelivo_device_identity_handle_close, kelivo_device_identity_public_keys,
    kelivo_device_key_agreement_public_key_validate, kelivo_device_login_proof_sign,
    kelivo_device_pairing_approval_accept, kelivo_device_pairing_approval_create,
    kelivo_device_registration_finish_create, kelivo_device_signing_public_key_validate,
    kelivo_device_state_open, kelivo_device_state_seal, kelivo_pending_pairing_bind,
    kelivo_pending_pairing_handle_close, kelivo_pending_pairing_start,
};
pub use opaque_client::{
    kelivo_opaque_client_login_finish, kelivo_opaque_client_login_start,
    kelivo_opaque_client_registration_finish, kelivo_opaque_client_registration_start,
    kelivo_opaque_client_state_close,
};
pub use recovery::{
    KelivoRecoveryCapsuleBinding, KelivoRecoveryMediaExportAuthority, kelivo_recovery_capsule_seal,
    kelivo_recovery_handle_close, kelivo_recovery_identity_generate, kelivo_recovery_media_export,
    kelivo_recovery_media_import_history_verify_and_capsule_open,
};

#[cfg(target_os = "windows")]
mod windows;
#[cfg(target_os = "windows")]
use windows as platform;
#[cfg(target_os = "android")]
mod android;
#[cfg(target_os = "android")]
use android as platform;
#[cfg(target_os = "ios")]
mod ios;
#[cfg(target_os = "ios")]
use ios as platform;

const ABI_VERSION: u32 = 15;
const CAPABILITIES_STRUCT_SIZE: u32 = 32;
const KEY_SLOT_ID_SIZE: usize = 16;
const KEY_POLICY_VERSION: u32 = 1;
const INVALID_KEY_HANDLE: u64 = 0;
const INVALID_OPAQUE_STATE_HANDLE: u64 = 0;
// Dart FFI 只稳定往返正 63 位整数；三位类型域让七类秘密句柄互不兼容。
const HANDLE_TAG_MASK: u64 = 0b111 << 60;
const HANDLE_SEQUENCE_MASK: u64 = (1_u64 << 60) - 1;
const HANDLE_RESERVED_MASK: u64 = 1_u64 << 63;
const KEY_HANDLE_TAG: u64 = 0b001 << 60;
const OPAQUE_STATE_HANDLE_TAG: u64 = 0b010 << 60;
const DEVICE_IDENTITY_HANDLE_TAG: u64 = 0b011 << 60;
const ACCOUNT_ROOT_KEY_HANDLE_TAG: u64 = 0b100 << 60;
const PENDING_PAIRING_HANDLE_TAG: u64 = 0b101 << 60;
const ATTACHMENT_DATA_KEY_HANDLE_TAG: u64 = 0b110 << 60;
const RECOVERY_HANDLE_TAG: u64 = 0b111 << 60;
const MAX_ACTIVE_KEY_HANDLES: usize = 1024;
const MAX_ACTIVE_OPAQUE_STATES: usize = 64;
const MAX_IN_FLIGHT_OPAQUE_FINISHES: usize = 1;
const OPAQUE_ACCOUNT_ID_SIZE: usize = 16;
const OPAQUE_REGISTRATION_REQUEST_SIZE: usize =
    kelivo_secure_core_protocol::REGISTRATION_REQUEST_LENGTH;
const OPAQUE_REGISTRATION_RESPONSE_SIZE: usize =
    kelivo_secure_core_protocol::REGISTRATION_RESPONSE_LENGTH;
const OPAQUE_REGISTRATION_UPLOAD_SIZE: usize =
    kelivo_secure_core_protocol::REGISTRATION_UPLOAD_LENGTH;
const OPAQUE_CREDENTIAL_REQUEST_SIZE: usize =
    kelivo_secure_core_protocol::CREDENTIAL_REQUEST_LENGTH;
const OPAQUE_CREDENTIAL_RESPONSE_SIZE: usize =
    kelivo_secure_core_protocol::CREDENTIAL_RESPONSE_LENGTH;
const OPAQUE_CREDENTIAL_FINALIZATION_SIZE: usize =
    kelivo_secure_core_protocol::CREDENTIAL_FINALIZATION_LENGTH;
#[cfg(any(target_os = "android", target_os = "ios", target_os = "windows"))]
const KEY_SLOTS_CAPABILITY: u64 = 1 << 0;
#[cfg(any(target_os = "android", target_os = "ios", target_os = "windows"))]
const BACKGROUND_ACCESS_CAPABILITY: u64 = 1 << 1;
#[cfg(any(target_os = "android", target_os = "ios", target_os = "windows"))]
const RECORD_ENVELOPES_CAPABILITY: u64 = 1 << 2;
#[cfg(any(target_os = "android", target_os = "ios", target_os = "windows"))]
const SQLCIPHER_KEY_APPLICATION_CAPABILITY: u64 = 1 << 3;
#[cfg(any(target_os = "android", target_os = "ios", target_os = "windows"))]
const SQLCIPHER_DATABASE_ATTACH_CAPABILITY: u64 = 1 << 4;
const OPAQUE_CLIENT_CAPABILITY: u64 = 1 << 5;
const DEVICE_E2EE_CORE_CAPABILITY: u64 = 1 << 6;
const ATTACHMENT_CRYPTO_CAPABILITY: u64 = 1 << 7;
const ACCOUNT_TRUST_SIGNING_CAPABILITY: u64 = 1 << 8;
const RECOVERY_MEDIA_CAPABILITY: u64 = 1 << 9;
pub(crate) const LOCAL_KEY_SIZE: usize = 32;

type LocalKey = Zeroizing<Box<[u8]>>;

#[cfg(not(any(target_os = "android", target_os = "ios", target_os = "windows")))]
mod platform {
    use super::{KelivoStatus, LocalKey};

    pub(super) const SECURE_STORAGE_BACKEND: u32 = 0;
    pub(super) const CAPABILITY_FLAGS: u64 = 0;

    pub(super) fn create_slot(_slot_id: &[u8; 16]) -> Result<LocalKey, KelivoStatus> {
        Err(KelivoStatus::UnsupportedPlatform)
    }

    pub(super) fn open_slot(_slot_id: &[u8; 16]) -> Result<LocalKey, KelivoStatus> {
        Err(KelivoStatus::UnsupportedPlatform)
    }

    pub(super) fn delete_slot(_slot_id: &[u8; 16]) -> Result<(), KelivoStatus> {
        Err(KelivoStatus::UnsupportedPlatform)
    }

    pub(super) fn fill_random(_output: &mut [u8]) -> Result<(), KelivoStatus> {
        Err(KelivoStatus::UnsupportedPlatform)
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct KelivoCoreCapabilities {
    pub struct_size: u32,
    pub abi_version: u32,
    pub flags: u64,
    pub secure_storage_backend: u32,
    pub reserved: [u32; 3],
}

const _: () =
    assert!(core::mem::size_of::<KelivoCoreCapabilities>() == CAPABILITIES_STRUCT_SIZE as usize);

#[repr(i32)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
// 单个平台只会构造状态全集的一部分，但所有产物必须保留同一套 ABI 数值。
#[allow(dead_code)]
pub(crate) enum KelivoStatus {
    Ok = 0,
    NullPointer = 1,
    InvalidSlotIdLength = 2,
    UnsupportedPolicy = 3,
    InvalidKeyHandle = 4,
    OutputBufferTooSmall = 5,
    SlotNotFound = 6,
    SlotAlreadyExists = 7,
    SlotDataInvalid = 8,
    SlotUnwrapFailed = 9,
    SecureStorageUnavailable = 10,
    RandomSourceFailure = 11,
    IoFailure = 12,
    InternalState = 13,
    InvalidRecordIdLength = 14,
    InvalidArgument = 15,
    RecordEnvelopeInvalid = 16,
    RecordAuthenticationFailed = 17,
    InputTooLarge = 18,
    SqlCipherKeyFailed = 19,
    SqlCipherAttachFailed = 20,
    InvalidOpaqueStateHandle = 21,
    OpaqueMessageInvalid = 22,
    OpaqueProtocolFailed = 23,
    TooManyActiveHandles = 24,
    HandleSpaceExhausted = 25,
    InvalidAccountId = 26,
    InvalidDeviceIdentityHandle = 27,
    InvalidAccountRootKeyHandle = 28,
    DeviceMessageInvalid = 29,
    DeviceAuthenticationFailed = 30,
    DeviceStateInvalid = 31,
    DeviceStateAuthenticationFailed = 32,
    InvalidPendingPairingHandle = 33,
    PairingExpired = 34,
    PendingPairingStateInvalid = 35,
    InvalidAttachmentDataKeyHandle = 36,
    AttachmentEnvelopeInvalid = 37,
    AttachmentAuthenticationFailed = 38,
    SlotInUse = 39,
    InvalidRecoveryHandle = 40,
    RecoveryCapsuleInvalid = 41,
    RecoveryCapsuleAuthenticationFailed = 42,
    RecoveryMediaInvalid = 43,
    RecoveryMediaAuthenticationFailed = 44,
    RecoveryGenesisInvalid = 45,
    RecoveryOriginMismatch = 46,
    RecoveryPassphraseInvalid = 47,
    RecoveryHistoryInvalid = 48,
    RecoveryHistoryAuthenticationFailed = 49,
    UnsupportedPlatform = 100,
}

impl KelivoStatus {
    const fn code(self) -> i32 {
        self as i32
    }
}

unsafe fn write_output<T>(output: *mut T, value: T) -> Result<(), KelivoStatus> {
    if output.is_null() {
        return Err(KelivoStatus::NullPointer);
    }

    // 调用方持有输出缓冲区；这里只在完成空指针检查后执行一次定点写入。
    unsafe {
        output.write(value);
    }
    Ok(())
}

unsafe fn read_input<'a>(input: *const u8, length: usize) -> Result<&'a [u8], KelivoStatus> {
    if length == 0 {
        return Ok(&[]);
    }
    if input.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    Ok(unsafe { slice::from_raw_parts(input, length) })
}

unsafe fn read_record_id(
    record_id: *const u8,
    record_id_length: usize,
) -> Result<[u8; record::RECORD_ID_SIZE], KelivoStatus> {
    if record_id.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    if record_id_length != record::RECORD_ID_SIZE {
        return Err(KelivoStatus::InvalidRecordIdLength);
    }
    let source = unsafe { slice::from_raw_parts(record_id, record::RECORD_ID_SIZE) };
    let mut validated = [0_u8; record::RECORD_ID_SIZE];
    validated.copy_from_slice(source);
    Ok(validated)
}

unsafe fn read_database_id(
    database_id: *const u8,
    database_id_length: usize,
) -> Result<[u8; database::DATABASE_ID_SIZE], KelivoStatus> {
    if database_id.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    if database_id_length != database::DATABASE_ID_SIZE {
        return Err(KelivoStatus::InvalidArgument);
    }
    let source = unsafe { slice::from_raw_parts(database_id, database::DATABASE_ID_SIZE) };
    let mut validated = [0_u8; database::DATABASE_ID_SIZE];
    validated.copy_from_slice(source);
    Ok(validated)
}

unsafe fn write_bytes(
    output: *mut u8,
    output_capacity: usize,
    value: &[u8],
    out_length: *mut usize,
) -> Result<(), KelivoStatus> {
    if output_capacity < value.len() {
        unsafe {
            write_output(out_length, value.len())?;
        }
        return Err(KelivoStatus::OutputBufferTooSmall);
    }
    if !value.is_empty() && output.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    if !value.is_empty() {
        unsafe {
            core::ptr::copy_nonoverlapping(value.as_ptr(), output, value.len());
        }
    }
    unsafe {
        write_output(out_length, value.len())?;
    }
    Ok(())
}

unsafe fn read_key_slot_id(
    slot_id: *const u8,
    slot_id_length: usize,
    policy_version: u32,
) -> Result<[u8; KEY_SLOT_ID_SIZE], KelivoStatus> {
    if slot_id.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    if slot_id_length != KEY_SLOT_ID_SIZE {
        return Err(KelivoStatus::InvalidSlotIdLength);
    }
    if policy_version != KEY_POLICY_VERSION {
        return Err(KelivoStatus::UnsupportedPolicy);
    }

    let source = unsafe { slice::from_raw_parts(slot_id, KEY_SLOT_ID_SIZE) };
    let mut validated = [0_u8; KEY_SLOT_ID_SIZE];
    validated.copy_from_slice(source);
    Ok(validated)
}

struct RegisteredKey {
    key: Arc<LocalKey>,
    // 删除按持久槽位判定；测试注入的临时密钥没有平台槽位身份。
    slot_id: Option<[u8; KEY_SLOT_ID_SIZE]>,
}

struct KeyRegistry {
    active: HashMap<u64, RegisteredKey>,
    next_sequence: u64,
}

impl Default for KeyRegistry {
    fn default() -> Self {
        Self {
            active: HashMap::new(),
            next_sequence: 1,
        }
    }
}

fn issue_typed_handle(tag: u64, next_sequence: &mut u64) -> Result<u64, KelivoStatus> {
    debug_assert_eq!(tag & HANDLE_TAG_MASK, tag);
    debug_assert_ne!(tag, 0);
    let sequence = *next_sequence;
    if sequence == 0 || sequence > HANDLE_SEQUENCE_MASK {
        return Err(KelivoStatus::HandleSpaceExhausted);
    }
    *next_sequence = if sequence == HANDLE_SEQUENCE_MASK {
        0
    } else {
        sequence + 1
    };
    Ok(tag | sequence)
}

fn handle_has_tag(handle: u64, tag: u64) -> bool {
    handle & HANDLE_RESERVED_MASK == 0
        && handle & HANDLE_TAG_MASK == tag
        && handle & HANDLE_SEQUENCE_MASK != 0
}

fn key_registry() -> &'static Mutex<KeyRegistry> {
    static REGISTRY: OnceLock<Mutex<KeyRegistry>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(KeyRegistry::default()))
}

#[cfg(test)]
fn register_key(key: LocalKey) -> Result<u64, KelivoStatus> {
    register_key_with_slot(key, None)
}

fn register_slot_key(key: LocalKey, slot_id: [u8; KEY_SLOT_ID_SIZE]) -> Result<u64, KelivoStatus> {
    register_key_with_slot(key, Some(slot_id))
}

fn register_key_with_slot(
    key: LocalKey,
    slot_id: Option<[u8; KEY_SLOT_ID_SIZE]>,
) -> Result<u64, KelivoStatus> {
    let mut registry = key_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;

    if registry.active.len() >= MAX_ACTIVE_KEY_HANDLES {
        return Err(KelivoStatus::TooManyActiveHandles);
    }
    let handle = issue_typed_handle(KEY_HANDLE_TAG, &mut registry.next_sequence)?;
    let replaced = registry.active.insert(
        handle,
        RegisteredKey {
            key: Arc::new(key),
            slot_id,
        },
    );
    debug_assert!(replaced.is_none());
    Ok(handle)
}

fn key_for_handle(handle: u64) -> Result<Arc<LocalKey>, KelivoStatus> {
    if !handle_has_tag(handle, KEY_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidKeyHandle);
    }
    key_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .get(&handle)
        .map(|entry| Arc::clone(&entry.key))
        .ok_or(KelivoStatus::InvalidKeyHandle)
}

fn close_key_handle(handle: u64) -> Result<(), KelivoStatus> {
    if !handle_has_tag(handle, KEY_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidKeyHandle);
    }

    let mut registry = key_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    let entry = registry
        .active
        .get(&handle)
        .ok_or(KelivoStatus::InvalidKeyHandle)?;
    // 新借用也必须取得同一把注册表锁；计数为一时才能原子移除并清零。
    if Arc::strong_count(&entry.key) != 1 {
        return Err(KelivoStatus::SlotInUse);
    }
    let removed = registry
        .active
        .remove(&handle)
        .ok_or(KelivoStatus::InternalState)?;
    drop(removed);
    Ok(())
}

fn ensure_slot_unused(slot_id: &[u8; KEY_SLOT_ID_SIZE]) -> Result<(), KelivoStatus> {
    let registry = key_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    if registry
        .active
        .values()
        .any(|entry| entry.slot_id.as_ref() == Some(slot_id))
    {
        Err(KelivoStatus::SlotInUse)
    } else {
        Ok(())
    }
}

fn key_slot_lifecycle_lock() -> &'static Mutex<()> {
    // 串行化同进程的打开、创建和擦除，避免删除检查与新句柄注册之间出现窗口。
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(()))
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_core_abi_version() -> u32 {
    ABI_VERSION
}

/// # Safety
///
/// `out_capabilities` 必须指向至少 `out_capabilities_size` 字节的可写内存。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_core_get_capabilities(
    out_capabilities: *mut KelivoCoreCapabilities,
    out_capabilities_size: usize,
) -> i32 {
    if out_capabilities.is_null() {
        return KelivoStatus::NullPointer.code();
    }
    if out_capabilities_size < size_of::<KelivoCoreCapabilities>() {
        return KelivoStatus::OutputBufferTooSmall.code();
    }

    let capabilities = KelivoCoreCapabilities {
        struct_size: CAPABILITIES_STRUCT_SIZE,
        abi_version: ABI_VERSION,
        flags: platform::CAPABILITY_FLAGS
            | OPAQUE_CLIENT_CAPABILITY
            | if cfg!(any(
                target_os = "android",
                target_os = "ios",
                target_os = "windows"
            )) {
                DEVICE_E2EE_CORE_CAPABILITY
                    | ATTACHMENT_CRYPTO_CAPABILITY
                    | ACCOUNT_TRUST_SIGNING_CAPABILITY
            } else {
                0
            }
            | if cfg!(any(target_os = "android", target_os = "ios")) {
                RECOVERY_MEDIA_CAPABILITY
            } else {
                0
            },
        secure_storage_backend: platform::SECURE_STORAGE_BACKEND,
        reserved: [0; 3],
    };

    match unsafe { write_output(out_capabilities, capabilities) } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

unsafe fn key_slot_operation(
    slot_id: *const u8,
    slot_id_length: usize,
    policy_version: u32,
    out_handle: *mut u64,
    create: bool,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_handle, INVALID_KEY_HANDLE) } {
        return status.code();
    }
    let slot_id = match unsafe { read_key_slot_id(slot_id, slot_id_length, policy_version) } {
        Ok(slot_id) => slot_id,
        Err(status) => return status.code(),
    };
    let _lifecycle_guard = match key_slot_lifecycle_lock().lock() {
        Ok(guard) => guard,
        Err(_) => return KelivoStatus::InternalState.code(),
    };

    let key = if create {
        platform::create_slot(&slot_id)
    } else {
        platform::open_slot(&slot_id)
    };
    let handle = match key.and_then(|key| register_slot_key(key, slot_id)) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };

    match unsafe { write_output(out_handle, handle) } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => {
            let _ = close_key_handle(handle);
            status.code()
        }
    }
}

/// # Safety
///
/// `slot_id` 必须指向 `slot_id_length` 字节的可读内存，`out_handle` 必须可写。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_key_slot_create(
    slot_id: *const u8,
    slot_id_length: usize,
    policy_version: u32,
    out_handle: *mut u64,
) -> i32 {
    unsafe { key_slot_operation(slot_id, slot_id_length, policy_version, out_handle, true) }
}

/// # Safety
///
/// `slot_id` 必须指向 `slot_id_length` 字节的可读内存，`out_handle` 必须可写。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_key_slot_open(
    slot_id: *const u8,
    slot_id_length: usize,
    policy_version: u32,
    out_handle: *mut u64,
) -> i32 {
    unsafe { key_slot_operation(slot_id, slot_id_length, policy_version, out_handle, false) }
}

/// # Safety
///
/// `slot_id` 必须指向 `slot_id_length` 字节的可读内存。目标槽位缺失时幂等
/// 成功；同进程仍持有该槽位句柄时拒绝删除。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_key_slot_delete(
    slot_id: *const u8,
    slot_id_length: usize,
    policy_version: u32,
) -> i32 {
    let slot_id = match unsafe { read_key_slot_id(slot_id, slot_id_length, policy_version) } {
        Ok(slot_id) => slot_id,
        Err(status) => return status.code(),
    };
    let _lifecycle_guard = match key_slot_lifecycle_lock().lock() {
        Ok(guard) => guard,
        Err(_) => return KelivoStatus::InternalState.code(),
    };
    if let Err(status) = ensure_slot_unused(&slot_id) {
        return status.code();
    }
    match platform::delete_slot(&slot_id) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_key_handle_close(handle: u64) -> i32 {
    match close_key_handle(handle) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

fn record_error_status(error: record::RecordError) -> KelivoStatus {
    match error {
        record::RecordError::AuthenticationFailed | record::RecordError::ContextMismatch => {
            KelivoStatus::RecordAuthenticationFailed
        }
        record::RecordError::Crypto => KelivoStatus::InternalState,
        record::RecordError::InputTooLarge => KelivoStatus::InputTooLarge,
        record::RecordError::InvalidInput => KelivoStatus::InvalidArgument,
        record::RecordError::InvalidEnvelope => KelivoStatus::RecordEnvelopeInvalid,
    }
}

fn master_key(key: &LocalKey) -> Result<&[u8; LOCAL_KEY_SIZE], KelivoStatus> {
    <&[u8; LOCAL_KEY_SIZE]>::try_from(&key[..]).map_err(|_| KelivoStatus::InternalState)
}

#[derive(Clone, Copy)]
enum RecordKeySource {
    LocalSlot,
    AccountRoot,
}

enum RecordMasterKey {
    LocalSlot(Arc<LocalKey>),
    AccountRoot(kelivo_secure_core_protocol::device_crypto::AccountRootKey),
}

impl RecordMasterKey {
    fn as_bytes(&self) -> Result<&[u8; 32], KelivoStatus> {
        match self {
            Self::LocalSlot(key) => master_key(key),
            Self::AccountRoot(ark) => Ok(ark.as_bytes()),
        }
    }
}

fn record_key_for_handle(
    handle: u64,
    source: RecordKeySource,
    epoch: u64,
) -> Result<RecordMasterKey, KelivoStatus> {
    match source {
        RecordKeySource::LocalSlot => key_for_handle(handle).map(RecordMasterKey::LocalSlot),
        RecordKeySource::AccountRoot => {
            let epoch = u32::try_from(epoch).map_err(|_| KelivoStatus::InvalidArgument)?;
            match device_core::ark_for_handle(handle, epoch) {
                Ok(key) => Ok(RecordMasterKey::AccountRoot(key)),
                Err(KelivoStatus::InvalidArgument) => Err(KelivoStatus::RecordAuthenticationFailed),
                Err(status) => Err(status),
            }
        }
    }
}

fn database_error_status(error: database::DatabaseKeyError) -> KelivoStatus {
    match error {
        database::DatabaseKeyError::Crypto => KelivoStatus::InternalState,
        database::DatabaseKeyError::InvalidInput => KelivoStatus::InvalidArgument,
        database::DatabaseKeyError::KeyCallbackFailed => KelivoStatus::SqlCipherKeyFailed,
        database::DatabaseKeyError::AttachCallbackFailed => KelivoStatus::SqlCipherAttachFailed,
    }
}

/// # Safety
///
/// `database_id` 必须覆盖声明的可读长度；`database` 必须是仍打开的 SQLite
/// 连接，`key_callback` 必须与该连接来自同一原生 SQLite 资产。回调只在本次
/// 调用内同步使用派生密钥，不得保存密钥指针。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_sqlcipher_key_apply(
    handle: u64,
    database_id: *const u8,
    database_id_length: usize,
    epoch: u64,
    database: *mut c_void,
    key_callback: Option<database::SqlCipherKeyCallback>,
) -> i32 {
    let database_id = match unsafe { read_database_id(database_id, database_id_length) } {
        Ok(database_id) => database_id,
        Err(status) => return status.code(),
    };
    if database.is_null() {
        return KelivoStatus::NullPointer.code();
    }
    let key_callback = match key_callback {
        Some(key_callback) => key_callback,
        None => return KelivoStatus::NullPointer.code(),
    };
    let key = match key_for_handle(handle) {
        Ok(key) => key,
        Err(status) => return status.code(),
    };
    let master_key = match master_key(&key) {
        Ok(master_key) => master_key,
        Err(status) => return status.code(),
    };
    match database::apply_database_key(master_key, &database_id, epoch, database, key_callback) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(error) => database_error_status(error).code(),
    }
}

/// # Safety
///
/// `database_id`、`database_path` 与 `database_name` 必须覆盖各自声明的可读
/// 长度；`database` 必须是仍打开且已设主库密钥的 SQLite 连接。所有回调必须
/// 与该连接来自同一原生 SQLite 资产，且只允许在本次同步调用内使用输入指针。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_sqlcipher_database_attach(
    handle: u64,
    database_id: *const u8,
    database_id_length: usize,
    epoch: u64,
    database: *mut c_void,
    database_path: *const u8,
    database_path_length: usize,
    database_name: *const u8,
    database_name_length: usize,
    prepare_callback: Option<database::SqlitePrepareCallback>,
    bind_text_callback: Option<database::SqliteBindTextCallback>,
    bind_blob_callback: Option<database::SqliteBindBlobCallback>,
    step_callback: Option<database::SqliteStepCallback>,
    finalize_callback: Option<database::SqliteFinalizeCallback>,
) -> i32 {
    let database_id = match unsafe { read_database_id(database_id, database_id_length) } {
        Ok(database_id) => database_id,
        Err(status) => return status.code(),
    };
    let database_path = match unsafe { read_input(database_path, database_path_length) } {
        Ok(database_path) => database_path,
        Err(status) => return status.code(),
    };
    let database_name = match unsafe { read_input(database_name, database_name_length) } {
        Ok(database_name) => database_name,
        Err(status) => return status.code(),
    };
    if database.is_null() {
        return KelivoStatus::NullPointer.code();
    }
    let prepare = match prepare_callback {
        Some(callback) => callback,
        None => return KelivoStatus::NullPointer.code(),
    };
    let bind_text = match bind_text_callback {
        Some(callback) => callback,
        None => return KelivoStatus::NullPointer.code(),
    };
    let bind_blob = match bind_blob_callback {
        Some(callback) => callback,
        None => return KelivoStatus::NullPointer.code(),
    };
    let step = match step_callback {
        Some(callback) => callback,
        None => return KelivoStatus::NullPointer.code(),
    };
    let finalize = match finalize_callback {
        Some(callback) => callback,
        None => return KelivoStatus::NullPointer.code(),
    };
    let key = match key_for_handle(handle) {
        Ok(key) => key,
        Err(status) => return status.code(),
    };
    let master_key = match master_key(&key) {
        Ok(master_key) => master_key,
        Err(status) => return status.code(),
    };
    match database::attach_database(
        master_key,
        &database_id,
        epoch,
        database,
        database_path,
        database_name,
        database::SqliteAttachCallbacks {
            prepare,
            bind_text,
            bind_blob,
            step,
            finalize,
        },
    ) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(error) => database_error_status(error).code(),
    }
}

/// # Safety
///
/// 所有输入指针必须覆盖声明的可读长度；输出指针必须覆盖声明的可写容量。
/// `out_envelope_length` 必须始终可写。输出容量不足时不会生成 nonce 或写入输出缓冲区。
// 该内部入口逐项镜像冻结的 C ABI，拆成参数对象会隐藏指针与长度的配对审计边界。
#[allow(clippy::too_many_arguments)]
unsafe fn record_seal_with_handle(
    key_source: RecordKeySource,
    handle: u64,
    record_id: *const u8,
    record_id_length: usize,
    epoch: u64,
    associated_data: *const u8,
    associated_data_length: usize,
    plaintext: *const u8,
    plaintext_length: usize,
    out_envelope: *mut u8,
    out_envelope_capacity: usize,
    out_envelope_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_envelope_length, 0) } {
        return status.code();
    }
    if associated_data_length > record::MAX_EXTERNAL_AAD_SIZE
        || plaintext_length > record::MAX_PLAINTEXT_SIZE
    {
        return KelivoStatus::InputTooLarge.code();
    }
    let record_id = match unsafe { read_record_id(record_id, record_id_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let associated_data = match unsafe { read_input(associated_data, associated_data_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let plaintext = match unsafe { read_input(plaintext, plaintext_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let key = match record_key_for_handle(handle, key_source, epoch) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let required = match record::envelope_size(epoch, plaintext.len()) {
        Ok(value) => value,
        Err(error) => return record_error_status(error).code(),
    };
    if out_envelope_capacity < required {
        return match unsafe { write_output(out_envelope_length, required) } {
            Ok(()) => KelivoStatus::OutputBufferTooSmall.code(),
            Err(status) => status.code(),
        };
    }
    if out_envelope.is_null() {
        return KelivoStatus::NullPointer.code();
    }

    let mut nonce = [0_u8; record::RECORD_NONCE_SIZE];
    if let Err(status) = platform::fill_random(&mut nonce) {
        return status.code();
    }
    let key = match key.as_bytes() {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let envelope =
        match record::seal_with_nonce(key, &record_id, epoch, associated_data, plaintext, &nonce) {
            Ok(value) => value,
            Err(error) => return record_error_status(error).code(),
        };
    match unsafe {
        write_bytes(
            out_envelope,
            out_envelope_capacity,
            &envelope,
            out_envelope_length,
        )
    } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

/// # Safety
///
/// 约束与 `record_seal_with_handle` 相同；句柄必须来自平台本地密钥槽。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_record_seal(
    handle: u64,
    record_id: *const u8,
    record_id_length: usize,
    epoch: u64,
    associated_data: *const u8,
    associated_data_length: usize,
    plaintext: *const u8,
    plaintext_length: usize,
    out_envelope: *mut u8,
    out_envelope_capacity: usize,
    out_envelope_length: *mut usize,
) -> i32 {
    unsafe {
        record_seal_with_handle(
            RecordKeySource::LocalSlot,
            handle,
            record_id,
            record_id_length,
            epoch,
            associated_data,
            associated_data_length,
            plaintext,
            plaintext_length,
            out_envelope,
            out_envelope_capacity,
            out_envelope_length,
        )
    }
}

/// # Safety
///
/// 约束与 `record_seal_with_handle` 相同；句柄必须是不透明账户根密钥句柄。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_account_record_seal(
    ark_handle: u64,
    record_id: *const u8,
    record_id_length: usize,
    key_epoch: u32,
    associated_data: *const u8,
    associated_data_length: usize,
    plaintext: *const u8,
    plaintext_length: usize,
    out_envelope: *mut u8,
    out_envelope_capacity: usize,
    out_envelope_length: *mut usize,
) -> i32 {
    unsafe {
        record_seal_with_handle(
            RecordKeySource::AccountRoot,
            ark_handle,
            record_id,
            record_id_length,
            u64::from(key_epoch),
            associated_data,
            associated_data_length,
            plaintext,
            plaintext_length,
            out_envelope,
            out_envelope_capacity,
            out_envelope_length,
        )
    }
}

/// # Safety
///
/// 所有输入指针必须覆盖声明的可读长度；输出指针必须覆盖声明的可写容量。
/// `out_plaintext_length` 必须始终可写；认证失败不得写出任何明文字节。
// 该内部入口逐项镜像冻结的 C ABI，拆成参数对象会隐藏指针与长度的配对审计边界。
#[allow(clippy::too_many_arguments)]
unsafe fn record_open_with_handle(
    key_source: RecordKeySource,
    handle: u64,
    record_id: *const u8,
    record_id_length: usize,
    epoch: u64,
    associated_data: *const u8,
    associated_data_length: usize,
    envelope: *const u8,
    envelope_length: usize,
    out_plaintext: *mut u8,
    out_plaintext_capacity: usize,
    out_plaintext_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_plaintext_length, 0) } {
        return status.code();
    }
    if associated_data_length > record::MAX_EXTERNAL_AAD_SIZE
        || envelope_length > record::MAX_ENVELOPE_SIZE
    {
        return KelivoStatus::InputTooLarge.code();
    }
    let record_id = match unsafe { read_record_id(record_id, record_id_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let associated_data = match unsafe { read_input(associated_data, associated_data_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let envelope = match unsafe { read_input(envelope, envelope_length) } {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let key = match record_key_for_handle(handle, key_source, epoch) {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let required = match record::opened_size(&record_id, epoch, envelope) {
        Ok(value) => value,
        Err(error) => return record_error_status(error).code(),
    };
    if out_plaintext_capacity < required {
        return match unsafe { write_output(out_plaintext_length, required) } {
            Ok(()) => KelivoStatus::OutputBufferTooSmall.code(),
            Err(status) => status.code(),
        };
    }
    if required > 0 && out_plaintext.is_null() {
        return KelivoStatus::NullPointer.code();
    }

    let key = match key.as_bytes() {
        Ok(value) => value,
        Err(status) => return status.code(),
    };
    let plaintext = match record::open(key, &record_id, epoch, associated_data, envelope) {
        Ok(value) => value,
        Err(error) => return record_error_status(error).code(),
    };
    match unsafe {
        write_bytes(
            out_plaintext,
            out_plaintext_capacity,
            &plaintext,
            out_plaintext_length,
        )
    } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

/// # Safety
///
/// 约束与 `record_open_with_handle` 相同；句柄必须来自平台本地密钥槽。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_record_open(
    handle: u64,
    record_id: *const u8,
    record_id_length: usize,
    epoch: u64,
    associated_data: *const u8,
    associated_data_length: usize,
    envelope: *const u8,
    envelope_length: usize,
    out_plaintext: *mut u8,
    out_plaintext_capacity: usize,
    out_plaintext_length: *mut usize,
) -> i32 {
    unsafe {
        record_open_with_handle(
            RecordKeySource::LocalSlot,
            handle,
            record_id,
            record_id_length,
            epoch,
            associated_data,
            associated_data_length,
            envelope,
            envelope_length,
            out_plaintext,
            out_plaintext_capacity,
            out_plaintext_length,
        )
    }
}

/// # Safety
///
/// 约束与 `record_open_with_handle` 相同；句柄必须是不透明账户根密钥句柄。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_account_record_open(
    ark_handle: u64,
    record_id: *const u8,
    record_id_length: usize,
    key_epoch: u32,
    associated_data: *const u8,
    associated_data_length: usize,
    envelope: *const u8,
    envelope_length: usize,
    out_plaintext: *mut u8,
    out_plaintext_capacity: usize,
    out_plaintext_length: *mut usize,
) -> i32 {
    unsafe {
        record_open_with_handle(
            RecordKeySource::AccountRoot,
            ark_handle,
            record_id,
            record_id_length,
            u64::from(key_epoch),
            associated_data,
            associated_data_length,
            envelope,
            envelope_length,
            out_plaintext,
            out_plaintext_capacity,
            out_plaintext_length,
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use core::ptr;
    #[cfg(target_os = "windows")]
    use core::{ffi::c_char, slice};
    use kelivo_secure_core_protocol::{
        device_crypto as crypto, recovery_crypto as recovery_protocol,
    };
    use sha2::{Digest, Sha256};

    fn empty_capabilities() -> KelivoCoreCapabilities {
        KelivoCoreCapabilities {
            struct_size: 0,
            abi_version: 0,
            flags: u64::MAX,
            secure_storage_backend: u32::MAX,
            reserved: [u32::MAX; 3],
        }
    }

    fn sentinel_device_state_binding() -> KelivoDeviceStateBinding {
        KelivoDeviceStateBinding {
            struct_size: u32::MAX,
            flags: u32::MAX,
            device_id: [0xa5; 16],
            key_version: u32::MAX,
            user_id: [0xa5; 16],
            key_epoch: u32::MAX,
        }
    }

    fn account_id(seed: u8) -> [u8; OPAQUE_ACCOUNT_ID_SIZE] {
        let mut value = [seed; OPAQUE_ACCOUNT_ID_SIZE];
        value[6] = (value[6] & 0x0f) | 0x40;
        value[8] = (value[8] & 0x3f) | 0x80;
        value
    }

    fn opaque_finish_test_guard() -> std::sync::MutexGuard<'static, ()> {
        static FINISH_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());
        // 生产约束只允许一个 Argon2 finish；相关单测必须在默认并行 runner 下确定执行。
        FINISH_TEST_LOCK
            .lock()
            .expect("OPAQUE 完成测试门禁不得中毒")
    }

    fn recovery_test_guard() -> std::sync::MutexGuard<'static, ()> {
        static RECOVERY_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());
        RECOVERY_TEST_LOCK.lock().expect("恢复介质测试门禁不得中毒")
    }

    fn sentinel_recovery_capsule_binding() -> KelivoRecoveryCapsuleBinding {
        KelivoRecoveryCapsuleBinding {
            struct_size: u32::MAX,
            user_id: [0xa5; 16],
            key_epoch: u32::MAX,
            capsule_version: u32::MAX,
        }
    }

    fn generate_test_recovery_identity(user_id: &[u8; 16]) -> (u64, [u8; 32]) {
        let mut handle = u64::MAX;
        let mut public_key = [0xa5; recovery_protocol::RECOVERY_PUBLIC_KEY_LENGTH];
        let mut public_key_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_recovery_identity_generate(
                    user_id.as_ptr(),
                    user_id.len(),
                    1,
                    &mut handle,
                    public_key.as_mut_ptr(),
                    public_key.len(),
                    &mut public_key_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(public_key_length, public_key.len());
        (handle, public_key)
    }

    fn seal_test_recovery_capsule(
        ark_handle: u64,
        user_id: &[u8; 16],
        key_epoch: u32,
        capsule_version: u32,
        recovery_public_key: &[u8; 32],
    ) -> [u8; recovery_protocol::RECOVERY_CAPSULE_LENGTH] {
        let mut capsule = [0xa5; recovery_protocol::RECOVERY_CAPSULE_LENGTH];
        let mut capsule_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_recovery_capsule_seal(
                    ark_handle,
                    user_id.as_ptr(),
                    user_id.len(),
                    key_epoch,
                    1,
                    capsule_version,
                    recovery_public_key.as_ptr(),
                    recovery_public_key.len(),
                    capsule.as_mut_ptr(),
                    capsule.len(),
                    &mut capsule_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(capsule_length, capsule.len());
        capsule
    }

    fn recovery_media_export_authority(
        ark_handle: u64,
        initial_capsule: [u8; recovery_protocol::RECOVERY_CAPSULE_LENGTH],
    ) -> KelivoRecoveryMediaExportAuthority {
        KelivoRecoveryMediaExportAuthority {
            struct_size: recovery::RECOVERY_MEDIA_EXPORT_AUTHORITY_STRUCT_SIZE,
            initial_capsule,
            local_epoch_one_ark_handle: ark_handle,
        }
    }

    fn build_test_recovery_genesis(
        ark_bytes: [u8; 32],
        user_id: [u8; 16],
        recovery_public_key: [u8; 32],
        capsule: &[u8; recovery_protocol::RECOVERY_CAPSULE_LENGTH],
    ) -> [u8; recovery_protocol::RECOVERY_GENESIS_LENGTH] {
        let user_id = crypto::UserId::new(user_id).expect("测试账户应有效");
        let ark = crypto::AccountRootKey::from_bytes(ark_bytes);
        let mut rng = kelivo_secure_core_protocol::system_rng().expect("测试随机源应可用");
        let member = crypto::DeviceIdentity::generate(&mut rng).expect("测试设备身份应生成");
        let member_public = member.public_keys();
        let binding = crypto::AccountTrustBinding {
            user_id,
            key_epoch: 1,
        };
        let trust_public =
            crypto::derive_account_trust_public_key(&ark, binding).expect("信任公钥应派生");
        let operation_id = account_id(0x65);
        let device_id = account_id(0x66);
        let mut genesis = [0_u8; recovery_protocol::RECOVERY_GENESIS_LENGTH];
        genesis[..8].copy_from_slice(b"KELIVOMM");
        genesis[8..12].copy_from_slice(&1_u32.to_be_bytes());
        genesis[12..28].copy_from_slice(user_id.as_bytes());
        genesis[28..32].copy_from_slice(&1_u32.to_be_bytes());
        genesis[32..36].copy_from_slice(&1_u32.to_be_bytes());
        genesis[68..100].copy_from_slice(trust_public.as_bytes());
        genesis[100..104].copy_from_slice(&1_u32.to_be_bytes());
        genesis[104..136].copy_from_slice(&recovery_public_key);
        genesis[136..140].copy_from_slice(&1_u32.to_be_bytes());
        genesis[140..172].copy_from_slice(&Sha256::digest(capsule));
        genesis[172..176].copy_from_slice(&1_u32.to_be_bytes());
        genesis[176..192].copy_from_slice(&operation_id);
        genesis[192..208].copy_from_slice(&device_id);
        genesis[208..224].copy_from_slice(&device_id);
        genesis[224..228].copy_from_slice(&1_u32.to_be_bytes());
        genesis[228..244].copy_from_slice(&device_id);
        genesis[244..248].copy_from_slice(&1_u32.to_be_bytes());
        genesis[252..284].copy_from_slice(member_public.signing.as_bytes());
        genesis[284..316].copy_from_slice(member_public.key_agreement.as_bytes());
        let signature = crypto::sign_account_trust_payload(&ark, binding, &genesis[..316])
            .expect("genesis 应签名");
        genesis[380..].copy_from_slice(signature.as_bytes());
        genesis
    }

    #[test]
    fn capabilities_reject_invalid_buffers_without_writing() {
        assert_eq!(
            unsafe {
                kelivo_core_get_capabilities(ptr::null_mut(), size_of::<KelivoCoreCapabilities>())
            },
            KelivoStatus::NullPointer.code()
        );

        let original = empty_capabilities();
        let mut output = original;
        assert_eq!(
            unsafe {
                kelivo_core_get_capabilities(&mut output, size_of::<KelivoCoreCapabilities>() - 1)
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        assert_eq!(output, original);
    }

    #[test]
    fn capabilities_write_the_fixed_v1_layout() {
        let mut output = empty_capabilities();
        assert_eq!(
            unsafe {
                kelivo_core_get_capabilities(&mut output, size_of::<KelivoCoreCapabilities>())
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            output.struct_size as usize,
            size_of::<KelivoCoreCapabilities>()
        );
        assert_eq!(output.abi_version, ABI_VERSION);
        assert_eq!(
            output.flags,
            platform::CAPABILITY_FLAGS
                | OPAQUE_CLIENT_CAPABILITY
                | if cfg!(any(
                    target_os = "android",
                    target_os = "ios",
                    target_os = "windows"
                )) {
                    DEVICE_E2EE_CORE_CAPABILITY
                        | ATTACHMENT_CRYPTO_CAPABILITY
                        | ACCOUNT_TRUST_SIGNING_CAPABILITY
                } else {
                    0
                }
                | if cfg!(any(target_os = "android", target_os = "ios")) {
                    RECOVERY_MEDIA_CAPABILITY
                } else {
                    0
                }
        );
        assert_eq!(
            output.secure_storage_backend,
            platform::SECURE_STORAGE_BACKEND
        );
        assert_eq!(output.reserved, [0; 3]);
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn windows_capabilities_require_dpapi_backend() {
        let mut output = empty_capabilities();
        assert_eq!(
            unsafe {
                kelivo_core_get_capabilities(&mut output, size_of::<KelivoCoreCapabilities>())
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(output.secure_storage_backend, 1);
        assert_eq!(
            output.flags,
            KEY_SLOTS_CAPABILITY
                | BACKGROUND_ACCESS_CAPABILITY
                | RECORD_ENVELOPES_CAPABILITY
                | SQLCIPHER_KEY_APPLICATION_CAPABILITY
                | SQLCIPHER_DATABASE_ATTACH_CAPABILITY
                | OPAQUE_CLIENT_CAPABILITY
                | DEVICE_E2EE_CORE_CAPABILITY
                | ATTACHMENT_CRYPTO_CAPABILITY
                | ACCOUNT_TRUST_SIGNING_CAPABILITY
        );
    }

    #[cfg(target_os = "ios")]
    #[test]
    fn ios_capabilities_require_keychain_backend() {
        let mut output = empty_capabilities();
        assert_eq!(
            unsafe {
                kelivo_core_get_capabilities(&mut output, size_of::<KelivoCoreCapabilities>())
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(output.secure_storage_backend, 4);
        assert_eq!(
            output.flags,
            KEY_SLOTS_CAPABILITY
                | BACKGROUND_ACCESS_CAPABILITY
                | RECORD_ENVELOPES_CAPABILITY
                | SQLCIPHER_KEY_APPLICATION_CAPABILITY
                | SQLCIPHER_DATABASE_ATTACH_CAPABILITY
                | OPAQUE_CLIENT_CAPABILITY
                | DEVICE_E2EE_CORE_CAPABILITY
                | ATTACHMENT_CRYPTO_CAPABILITY
                | ACCOUNT_TRUST_SIGNING_CAPABILITY
        );
    }

    #[test]
    fn key_slot_create_rejects_every_invalid_boundary() {
        let slot_id = [0_u8; KEY_SLOT_ID_SIZE];
        let mut handle = 42_u64;

        assert_eq!(
            unsafe {
                kelivo_key_slot_create(
                    slot_id.as_ptr(),
                    slot_id.len(),
                    KEY_POLICY_VERSION,
                    ptr::null_mut(),
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(
            unsafe {
                kelivo_key_slot_create(ptr::null(), slot_id.len(), KEY_POLICY_VERSION, &mut handle)
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(handle, INVALID_KEY_HANDLE);

        handle = 42;
        assert_eq!(
            unsafe {
                kelivo_key_slot_create(
                    slot_id.as_ptr(),
                    slot_id.len() - 1,
                    KEY_POLICY_VERSION,
                    &mut handle,
                )
            },
            KelivoStatus::InvalidSlotIdLength.code()
        );
        assert_eq!(handle, INVALID_KEY_HANDLE);

        handle = 42;
        assert_eq!(
            unsafe {
                kelivo_key_slot_create(
                    slot_id.as_ptr(),
                    slot_id.len(),
                    KEY_POLICY_VERSION + 1,
                    &mut handle,
                )
            },
            KelivoStatus::UnsupportedPolicy.code()
        );
        assert_eq!(handle, INVALID_KEY_HANDLE);
    }

    #[test]
    fn key_slot_delete_rejects_every_invalid_boundary() {
        let slot_id = [0_u8; KEY_SLOT_ID_SIZE];

        assert_eq!(
            unsafe { kelivo_key_slot_delete(ptr::null(), slot_id.len(), KEY_POLICY_VERSION) },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(
            unsafe {
                kelivo_key_slot_delete(slot_id.as_ptr(), slot_id.len() - 1, KEY_POLICY_VERSION)
            },
            KelivoStatus::InvalidSlotIdLength.code()
        );
        assert_eq!(
            unsafe {
                kelivo_key_slot_delete(slot_id.as_ptr(), slot_id.len(), KEY_POLICY_VERSION + 1)
            },
            KelivoStatus::UnsupportedPolicy.code()
        );
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn key_slot_delete_requires_closed_handles_and_is_idempotent() {
        let mut slot_id = [0_u8; KEY_SLOT_ID_SIZE];
        platform::fill_random(&mut slot_id).expect("删除测试槽位标识应生成成功");
        assert_eq!(
            unsafe { kelivo_key_slot_delete(slot_id.as_ptr(), slot_id.len(), KEY_POLICY_VERSION,) },
            KelivoStatus::Ok.code()
        );

        let mut handle = INVALID_KEY_HANDLE;
        assert_eq!(
            unsafe {
                kelivo_key_slot_create(
                    slot_id.as_ptr(),
                    slot_id.len(),
                    KEY_POLICY_VERSION,
                    &mut handle,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_ne!(handle, INVALID_KEY_HANDLE);
        assert_eq!(
            unsafe { kelivo_key_slot_delete(slot_id.as_ptr(), slot_id.len(), KEY_POLICY_VERSION,) },
            KelivoStatus::SlotInUse.code()
        );
        assert_eq!(kelivo_key_handle_close(handle), KelivoStatus::Ok.code());
        assert_eq!(
            unsafe { kelivo_key_slot_delete(slot_id.as_ptr(), slot_id.len(), KEY_POLICY_VERSION,) },
            KelivoStatus::Ok.code()
        );

        let mut reopened_handle = 42_u64;
        assert_eq!(
            unsafe {
                kelivo_key_slot_open(
                    slot_id.as_ptr(),
                    slot_id.len(),
                    KEY_POLICY_VERSION,
                    &mut reopened_handle,
                )
            },
            KelivoStatus::SlotNotFound.code()
        );
        assert_eq!(reopened_handle, INVALID_KEY_HANDLE);
        assert_eq!(
            unsafe { kelivo_key_slot_delete(slot_id.as_ptr(), slot_id.len(), KEY_POLICY_VERSION,) },
            KelivoStatus::Ok.code()
        );
    }

    #[cfg(not(any(target_os = "android", target_os = "ios", target_os = "windows")))]
    #[test]
    fn unsupported_platform_key_slots_fail_closed() {
        let slot_id = [0_u8; KEY_SLOT_ID_SIZE];
        let mut handle = 42_u64;
        assert_eq!(
            unsafe {
                kelivo_key_slot_create(
                    slot_id.as_ptr(),
                    slot_id.len(),
                    KEY_POLICY_VERSION,
                    &mut handle,
                )
            },
            KelivoStatus::UnsupportedPlatform.code()
        );
        assert_eq!(handle, INVALID_KEY_HANDLE);
        assert_eq!(
            unsafe { kelivo_key_slot_delete(slot_id.as_ptr(), slot_id.len(), KEY_POLICY_VERSION,) },
            KelivoStatus::UnsupportedPlatform.code()
        );
        assert_eq!(
            kelivo_key_handle_close(INVALID_KEY_HANDLE),
            KelivoStatus::InvalidKeyHandle.code()
        );
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn key_handles_close_once_and_never_reuse_values() {
        let first = register_key(Zeroizing::new(vec![1; LOCAL_KEY_SIZE].into_boxed_slice()))
            .expect("首个密钥句柄应注册成功");
        assert_ne!(first, INVALID_KEY_HANDLE);
        let borrowed = key_for_handle(first).expect("活动句柄应允许借用密钥");
        assert_eq!(
            kelivo_key_handle_close(first),
            KelivoStatus::SlotInUse.code()
        );
        drop(borrowed);
        assert_eq!(kelivo_key_handle_close(first), KelivoStatus::Ok.code());
        assert_eq!(
            kelivo_key_handle_close(first),
            KelivoStatus::InvalidKeyHandle.code()
        );

        let second = register_key(Zeroizing::new(vec![2; LOCAL_KEY_SIZE].into_boxed_slice()))
            .expect("第二个密钥句柄应注册成功");
        assert_ne!(second, first);
        assert_eq!(kelivo_key_handle_close(second), KelivoStatus::Ok.code());
    }

    #[cfg(target_os = "windows")]
    unsafe extern "C" fn accept_sqlcipher_key(
        database: *mut c_void,
        key: *const c_void,
        key_length: i32,
    ) -> i32 {
        i32::from(database.is_null() || key.is_null() || key_length != LOCAL_KEY_SIZE as i32)
    }

    #[cfg(target_os = "windows")]
    unsafe extern "C" fn reject_sqlcipher_key(
        _database: *mut c_void,
        _key: *const c_void,
        _key_length: i32,
    ) -> i32 {
        26
    }

    #[cfg(target_os = "windows")]
    unsafe extern "C" fn accept_sqlite_prepare(
        database: *mut c_void,
        sql: *const c_char,
        sql_length: i32,
        out_statement: *mut *mut c_void,
        sql_tail: *mut *const c_char,
    ) -> i32 {
        if database.is_null()
            || sql.is_null()
            || sql_length <= 0
            || out_statement.is_null()
            || !sql_tail.is_null()
        {
            return 1;
        }
        let sql = unsafe { slice::from_raw_parts(sql.cast::<u8>(), sql_length as usize) };
        if sql != b"ATTACH DATABASE ? AS \"backup_probe\" KEY ?;" {
            return 1;
        }
        unsafe {
            out_statement.write(database);
        }
        0
    }

    #[cfg(target_os = "windows")]
    unsafe extern "C" fn accept_sqlite_bind_text(
        statement: *mut c_void,
        index: i32,
        value: *const c_char,
        value_length: i32,
        destructor: Option<database::SqliteDestructor>,
    ) -> i32 {
        i32::from(
            statement.is_null()
                || index != 1
                || value.is_null()
                || value_length <= 0
                || destructor.is_some(),
        )
    }

    #[cfg(target_os = "windows")]
    unsafe extern "C" fn accept_sqlite_bind_blob(
        statement: *mut c_void,
        index: i32,
        value: *const c_void,
        value_length: i32,
        destructor: Option<database::SqliteDestructor>,
    ) -> i32 {
        i32::from(
            statement.is_null()
                || index != 2
                || value.is_null()
                || value_length != LOCAL_KEY_SIZE as i32
                || destructor.is_some(),
        )
    }

    #[cfg(target_os = "windows")]
    unsafe extern "C" fn accept_sqlite_step(statement: *mut c_void) -> i32 {
        if statement.is_null() { 1 } else { 101 }
    }

    #[cfg(target_os = "windows")]
    unsafe extern "C" fn reject_sqlite_step(_statement: *mut c_void) -> i32 {
        26
    }

    #[cfg(target_os = "windows")]
    unsafe extern "C" fn accept_sqlite_finalize(statement: *mut c_void) -> i32 {
        i32::from(statement.is_null())
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn opaque_handle_applies_sqlcipher_key_through_callback() {
        let handle = register_key(Zeroizing::new(
            (0_u8..LOCAL_KEY_SIZE as u8)
                .collect::<Vec<_>>()
                .into_boxed_slice(),
        ))
        .expect("测试密钥句柄应注册成功");
        let database_id = [0x42_u8; database::DATABASE_ID_SIZE];
        let mut database_marker = 0_u8;
        let database = (&mut database_marker as *mut u8).cast::<c_void>();

        assert_eq!(
            unsafe {
                kelivo_sqlcipher_key_apply(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    1,
                    database,
                    Some(accept_sqlcipher_key),
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_key_apply(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    0,
                    database,
                    Some(accept_sqlcipher_key),
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_key_apply(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    1,
                    database,
                    Some(reject_sqlcipher_key),
                )
            },
            KelivoStatus::SqlCipherKeyFailed.code()
        );
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_key_apply(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    1,
                    ptr::null_mut(),
                    Some(accept_sqlcipher_key),
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_key_apply(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    1,
                    database,
                    None,
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_key_apply(
                    handle,
                    ptr::null(),
                    database_id.len(),
                    1,
                    database,
                    Some(accept_sqlcipher_key),
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_key_apply(
                    handle,
                    database_id.as_ptr(),
                    database_id.len() - 1,
                    1,
                    database,
                    Some(accept_sqlcipher_key),
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(kelivo_key_handle_close(handle), KelivoStatus::Ok.code());
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_key_apply(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    1,
                    database,
                    Some(accept_sqlcipher_key),
                )
            },
            KelivoStatus::InvalidKeyHandle.code()
        );
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn opaque_handle_attaches_sqlcipher_database_through_callbacks() {
        let handle = register_key(Zeroizing::new(
            (0_u8..LOCAL_KEY_SIZE as u8)
                .collect::<Vec<_>>()
                .into_boxed_slice(),
        ))
        .expect("测试密钥句柄应注册成功");
        let database_id = [0x42_u8; database::DATABASE_ID_SIZE];
        let database_path = b"Cargo.toml";
        let database_name = b"backup_probe";
        let mut database_marker = 0_u8;
        let database = (&mut database_marker as *mut u8).cast::<c_void>();

        assert_eq!(
            unsafe {
                kelivo_sqlcipher_database_attach(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    1,
                    database,
                    database_path.as_ptr(),
                    database_path.len(),
                    database_name.as_ptr(),
                    database_name.len(),
                    Some(accept_sqlite_prepare),
                    Some(accept_sqlite_bind_text),
                    Some(accept_sqlite_bind_blob),
                    Some(accept_sqlite_step),
                    Some(accept_sqlite_finalize),
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_database_attach(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    1,
                    database,
                    database_path.as_ptr(),
                    database_path.len(),
                    b"main".as_ptr(),
                    b"main".len(),
                    Some(accept_sqlite_prepare),
                    Some(accept_sqlite_bind_text),
                    Some(accept_sqlite_bind_blob),
                    Some(accept_sqlite_step),
                    Some(accept_sqlite_finalize),
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_database_attach(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    1,
                    database,
                    ptr::null(),
                    database_path.len(),
                    database_name.as_ptr(),
                    database_name.len(),
                    Some(accept_sqlite_prepare),
                    Some(accept_sqlite_bind_text),
                    Some(accept_sqlite_bind_blob),
                    Some(accept_sqlite_step),
                    Some(accept_sqlite_finalize),
                )
            },
            KelivoStatus::NullPointer.code()
        );
        let missing_database_path = b"missing-secure-core-database.sqlite";
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_database_attach(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    1,
                    database,
                    missing_database_path.as_ptr(),
                    missing_database_path.len(),
                    database_name.as_ptr(),
                    database_name.len(),
                    Some(accept_sqlite_prepare),
                    Some(accept_sqlite_bind_text),
                    Some(accept_sqlite_bind_blob),
                    Some(accept_sqlite_step),
                    Some(accept_sqlite_finalize),
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(
            unsafe {
                kelivo_sqlcipher_database_attach(
                    handle,
                    database_id.as_ptr(),
                    database_id.len(),
                    1,
                    database,
                    database_path.as_ptr(),
                    database_path.len(),
                    database_name.as_ptr(),
                    database_name.len(),
                    Some(accept_sqlite_prepare),
                    Some(accept_sqlite_bind_text),
                    Some(accept_sqlite_bind_blob),
                    Some(reject_sqlite_step),
                    Some(accept_sqlite_finalize),
                )
            },
            KelivoStatus::SqlCipherAttachFailed.code()
        );
        assert_eq!(kelivo_key_handle_close(handle), KelivoStatus::Ok.code());
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn opaque_handle_seals_and_opens_record_through_c_abi() {
        let handle = register_key(Zeroizing::new(
            (0_u8..LOCAL_KEY_SIZE as u8)
                .collect::<Vec<_>>()
                .into_boxed_slice(),
        ))
        .expect("测试密钥句柄应注册成功");
        let record_id = [0x41_u8; 16];
        let aad = b"account/vault/record";
        let plaintext = b"record payload";

        let mut envelope_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_record_seal(
                    handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    1,
                    aad.as_ptr(),
                    aad.len(),
                    plaintext.as_ptr(),
                    plaintext.len(),
                    ptr::null_mut(),
                    0,
                    &mut envelope_length,
                )
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        assert!(envelope_length > plaintext.len());

        let mut envelope = vec![0_u8; envelope_length];
        assert_eq!(
            unsafe {
                kelivo_record_seal(
                    handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    1,
                    aad.as_ptr(),
                    aad.len(),
                    plaintext.as_ptr(),
                    plaintext.len(),
                    envelope.as_mut_ptr(),
                    envelope.len(),
                    &mut envelope_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        envelope.truncate(envelope_length);

        let mut opened_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_record_open(
                    handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    1,
                    aad.as_ptr(),
                    aad.len(),
                    envelope.as_ptr(),
                    envelope.len(),
                    ptr::null_mut(),
                    0,
                    &mut opened_length,
                )
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        assert_eq!(opened_length, plaintext.len());

        let mut opened = vec![0_u8; opened_length];
        assert_eq!(
            unsafe {
                kelivo_record_open(
                    handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    1,
                    aad.as_ptr(),
                    aad.len(),
                    envelope.as_ptr(),
                    envelope.len(),
                    opened.as_mut_ptr(),
                    opened.len(),
                    &mut opened_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        opened.truncate(opened_length);
        assert_eq!(opened, plaintext);

        let mut tampered_envelope = envelope.clone();
        let last_index = tampered_envelope.len() - 1;
        tampered_envelope[last_index] ^= 1;
        let mut rejected_output = vec![0xa5_u8; plaintext.len()];
        let mut rejected_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_record_open(
                    handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    1,
                    aad.as_ptr(),
                    aad.len(),
                    tampered_envelope.as_ptr(),
                    tampered_envelope.len(),
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::RecordAuthenticationFailed.code()
        );
        assert_eq!(rejected_length, 0);
        assert!(rejected_output.iter().all(|value| *value == 0xa5));

        let mut unsupported_version = envelope.clone();
        unsupported_version[1] = 2;
        assert_eq!(
            unsafe {
                kelivo_record_open(
                    handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    1,
                    aad.as_ptr(),
                    aad.len(),
                    unsupported_version.as_ptr(),
                    unsupported_version.len(),
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::RecordEnvelopeInvalid.code()
        );
        assert_eq!(rejected_length, 0);
        assert!(rejected_output.iter().all(|value| *value == 0xa5));

        assert_eq!(kelivo_key_handle_close(handle), KelivoStatus::Ok.code());
        assert_eq!(
            unsafe {
                kelivo_record_open(
                    handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    1,
                    aad.as_ptr(),
                    aad.len(),
                    envelope.as_ptr(),
                    envelope.len(),
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::InvalidKeyHandle.code()
        );
        assert_eq!(rejected_length, 0);
        assert!(rejected_output.iter().all(|value| *value == 0xa5));
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn account_root_handle_seals_and_opens_record_through_c_abi() {
        let user_id = account_id(0x50);
        let mut ark_handle = 0_u64;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_generate(
                    user_id.as_ptr(),
                    user_id.len(),
                    KEY_EPOCH,
                    &mut ark_handle,
                )
            },
            KelivoStatus::Ok.code()
        );
        let record_id = [0x51_u8; 16];
        let aad = b"account/vault/record";
        let plaintext = b"shared record payload";
        const KEY_EPOCH: u32 = 7;

        let mut envelope_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_account_record_seal(
                    ark_handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    KEY_EPOCH,
                    aad.as_ptr(),
                    aad.len(),
                    plaintext.as_ptr(),
                    plaintext.len(),
                    ptr::null_mut(),
                    0,
                    &mut envelope_length,
                )
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        let mut envelope = vec![0_u8; envelope_length];
        assert_eq!(
            unsafe {
                kelivo_account_record_seal(
                    ark_handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    KEY_EPOCH,
                    aad.as_ptr(),
                    aad.len(),
                    plaintext.as_ptr(),
                    plaintext.len(),
                    envelope.as_mut_ptr(),
                    envelope.len(),
                    &mut envelope_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        envelope.truncate(envelope_length);

        let mut opened_length = plaintext.len();
        let mut opened = vec![0_u8; opened_length];
        assert_eq!(
            unsafe {
                kelivo_account_record_open(
                    ark_handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    KEY_EPOCH,
                    aad.as_ptr(),
                    aad.len(),
                    envelope.as_ptr(),
                    envelope.len(),
                    opened.as_mut_ptr(),
                    opened.len(),
                    &mut opened_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        opened.truncate(opened_length);
        assert_eq!(opened, plaintext);

        let mut other_ark_handle = 0_u64;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_generate(
                    user_id.as_ptr(),
                    user_id.len(),
                    KEY_EPOCH,
                    &mut other_ark_handle,
                )
            },
            KelivoStatus::Ok.code()
        );
        let mut rejected_length = usize::MAX;
        let mut rejected_output = vec![0xa5_u8; plaintext.len()];
        assert_eq!(
            unsafe {
                kelivo_account_record_open(
                    other_ark_handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    KEY_EPOCH,
                    aad.as_ptr(),
                    aad.len(),
                    envelope.as_ptr(),
                    envelope.len(),
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::RecordAuthenticationFailed.code()
        );
        assert_eq!(rejected_length, 0);
        assert!(rejected_output.iter().all(|value| *value == 0xa5));

        assert_eq!(
            unsafe {
                kelivo_record_open(
                    ark_handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    u64::from(KEY_EPOCH),
                    aad.as_ptr(),
                    aad.len(),
                    envelope.as_ptr(),
                    envelope.len(),
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::InvalidKeyHandle.code()
        );
        assert_eq!(rejected_length, 0);

        assert_eq!(
            kelivo_account_root_key_handle_close(other_ark_handle),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(ark_handle),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            unsafe {
                kelivo_account_record_open(
                    ark_handle,
                    record_id.as_ptr(),
                    record_id.len(),
                    KEY_EPOCH,
                    aad.as_ptr(),
                    aad.len(),
                    envelope.as_ptr(),
                    envelope.len(),
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::InvalidAccountRootKeyHandle.code()
        );
        assert_eq!(rejected_length, 0);
        assert!(rejected_output.iter().all(|value| *value == 0xa5));
    }

    #[test]
    fn opaque_registration_start_zeroes_outputs_before_rejecting_password() {
        let mut handle = 42_u64;
        let mut request_length = usize::MAX;
        let mut request = [0xa5_u8; OPAQUE_REGISTRATION_REQUEST_SIZE];

        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    ptr::null(),
                    0,
                    &mut handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(handle, INVALID_OPAQUE_STATE_HANDLE);
        assert_eq!(request_length, 0);
        assert!(request.iter().all(|value| *value == 0xa5));
    }

    #[test]
    fn opaque_start_rejects_pointer_and_length_boundaries_without_partial_output() {
        let password = b"registration-password";
        let mut handle = 42_u64;
        let mut request_length = usize::MAX;
        let mut request = [0xa5_u8; OPAQUE_REGISTRATION_REQUEST_SIZE];

        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    password.len(),
                    ptr::null_mut(),
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(request_length, 0);
        assert!(request.iter().all(|value| *value == 0xa5));

        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    password.len(),
                    &mut handle,
                    request.as_mut_ptr(),
                    request.len(),
                    ptr::null_mut(),
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(handle, INVALID_OPAQUE_STATE_HANDLE);

        handle = 42;
        request_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    password.len(),
                    &mut handle,
                    ptr::null_mut(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(handle, INVALID_OPAQUE_STATE_HANDLE);
        assert_eq!(request_length, 0);

        handle = 42;
        request_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    password.len(),
                    &mut handle,
                    request.as_mut_ptr(),
                    request.len() - 1,
                    &mut request_length,
                )
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        assert_eq!(handle, INVALID_OPAQUE_STATE_HANDLE);
        assert_eq!(request_length, 0);
        assert!(request.iter().all(|value| *value == 0xa5));

        handle = 42;
        request_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    ptr::null(),
                    1,
                    &mut handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(handle, INVALID_OPAQUE_STATE_HANDLE);
        assert_eq!(request_length, 0);

        handle = 42;
        request_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    kelivo_secure_core_protocol::MAX_OPAQUE_INPUT_LENGTH + 1,
                    &mut handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::InputTooLarge.code()
        );
        assert_eq!(handle, INVALID_OPAQUE_STATE_HANDLE);
        assert_eq!(request_length, 0);
    }

    #[test]
    fn opaque_client_state_handle_can_be_cancelled_exactly_once() {
        let password = b"registration-password";
        let mut handle = INVALID_OPAQUE_STATE_HANDLE;
        let mut request_length = 0_usize;
        let mut request = [0_u8; OPAQUE_REGISTRATION_REQUEST_SIZE];

        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    password.len(),
                    &mut handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_ne!(handle, INVALID_OPAQUE_STATE_HANDLE);
        assert_eq!(request_length, request.len());
        assert_eq!(
            kelivo_opaque_client_state_close(handle),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_opaque_client_state_close(handle),
            KelivoStatus::InvalidOpaqueStateHandle.code()
        );
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn key_and_opaque_handles_use_disjoint_non_reusable_namespaces() {
        let key_handle = register_key(Zeroizing::new(
            vec![0x41; LOCAL_KEY_SIZE].into_boxed_slice(),
        ))
        .expect("密钥句柄应注册成功");
        let password = b"registration-password";
        let mut opaque_handle = INVALID_OPAQUE_STATE_HANDLE;
        let mut request = [0_u8; OPAQUE_REGISTRATION_REQUEST_SIZE];
        let mut request_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    password.len(),
                    &mut opaque_handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::Ok.code()
        );

        assert!(handle_has_tag(key_handle, KEY_HANDLE_TAG));
        assert!(handle_has_tag(opaque_handle, OPAQUE_STATE_HANDLE_TAG));
        assert_ne!(key_handle, opaque_handle);
        assert_eq!(
            kelivo_key_handle_close(opaque_handle),
            KelivoStatus::InvalidKeyHandle.code()
        );
        assert_eq!(
            kelivo_opaque_client_state_close(key_handle),
            KelivoStatus::InvalidOpaqueStateHandle.code()
        );
        assert_eq!(
            kelivo_opaque_client_state_close(opaque_handle),
            KelivoStatus::Ok.code()
        );
        assert_eq!(kelivo_key_handle_close(key_handle), KelivoStatus::Ok.code());
    }

    #[test]
    fn typed_handle_sequence_fails_explicitly_at_exhaustion() {
        let mut sequence = HANDLE_SEQUENCE_MASK;
        assert_eq!(
            issue_typed_handle(OPAQUE_STATE_HANDLE_TAG, &mut sequence),
            Ok(OPAQUE_STATE_HANDLE_TAG | HANDLE_SEQUENCE_MASK)
        );
        assert_eq!(sequence, 0);
        assert_eq!(
            issue_typed_handle(OPAQUE_STATE_HANDLE_TAG, &mut sequence),
            Err(KelivoStatus::HandleSpaceExhausted)
        );
    }

    #[test]
    fn opaque_registration_finish_returns_only_public_upload_and_consumes_state() {
        let _finish_test_guard = opaque_finish_test_guard();
        let password = b"registration-password";
        let credential_identifier = account_id(0x17);
        let mut handle = INVALID_OPAQUE_STATE_HANDLE;
        let mut request_length = 0_usize;
        let mut request = [0_u8; OPAQUE_REGISTRATION_REQUEST_SIZE];
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    password.len(),
                    &mut handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::Ok.code()
        );

        let mut server_rng = kelivo_secure_core_protocol::system_rng().expect("服务端随机源应可用");
        let setup = kelivo_secure_core_protocol::generate_server_setup(&mut server_rng)
            .expect("服务端配置应生成");
        let response = kelivo_secure_core_protocol::server_registration_start(
            &setup,
            kelivo_secure_core_protocol::RegistrationRequest::from_bytes(&request)
                .expect("注册请求应可解析"),
            kelivo_secure_core_protocol::AccountBinding::new(&credential_identifier)
                .expect("账户绑定应有效"),
        )
        .expect("服务端注册响应应生成");

        let mut upload = [0_u8; OPAQUE_REGISTRATION_UPLOAD_SIZE];
        let mut upload_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_finish(
                    handle,
                    password.as_ptr(),
                    password.len(),
                    response.as_bytes().as_ptr(),
                    response.as_bytes().len(),
                    credential_identifier.as_ptr(),
                    credential_identifier.len(),
                    upload.as_mut_ptr(),
                    upload.len(),
                    &mut upload_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(upload_length, upload.len());
        let registration = kelivo_secure_core_protocol::RegistrationUpload::from_bytes(&upload)
            .and_then(kelivo_secure_core_protocol::server_registration_finish)
            .expect("上传消息应形成服务端注册记录");
        assert_eq!(
            registration.as_bytes().len(),
            kelivo_secure_core_protocol::REGISTRATION_UPLOAD_LENGTH
        );
        assert_eq!(
            kelivo_opaque_client_state_close(handle),
            KelivoStatus::InvalidOpaqueStateHandle.code()
        );
    }

    #[test]
    fn opaque_registration_finish_failure_zeroes_output_and_consumes_state() {
        let _finish_test_guard = opaque_finish_test_guard();
        let password = b"registration-password";
        let credential_identifier = account_id(0x27);
        let mut handle = INVALID_OPAQUE_STATE_HANDLE;
        let mut request_length = 0_usize;
        let mut request = [0_u8; OPAQUE_REGISTRATION_REQUEST_SIZE];
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    password.len(),
                    &mut handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::Ok.code()
        );

        let malformed_response = [0_u8; OPAQUE_REGISTRATION_RESPONSE_SIZE];
        let mut upload = [0xa5_u8; OPAQUE_REGISTRATION_UPLOAD_SIZE];
        let mut upload_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_finish(
                    handle,
                    password.as_ptr(),
                    password.len(),
                    malformed_response.as_ptr(),
                    malformed_response.len(),
                    credential_identifier.as_ptr(),
                    credential_identifier.len(),
                    upload.as_mut_ptr(),
                    upload.len(),
                    &mut upload_length,
                )
            },
            KelivoStatus::OpaqueMessageInvalid.code()
        );
        assert_eq!(upload_length, 0);
        assert!(upload.iter().all(|value| *value == 0xa5));
        assert_eq!(
            kelivo_opaque_client_state_close(handle),
            KelivoStatus::InvalidOpaqueStateHandle.code()
        );
    }

    #[test]
    fn opaque_finish_consumes_state_before_rejecting_output_capacity() {
        let _finish_test_guard = opaque_finish_test_guard();
        let password = b"registration-password";
        let mut handle = INVALID_OPAQUE_STATE_HANDLE;
        let mut request_length = 0_usize;
        let mut request = [0_u8; OPAQUE_REGISTRATION_REQUEST_SIZE];
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    password.len(),
                    &mut handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::Ok.code()
        );

        let response = [0_u8; OPAQUE_REGISTRATION_RESPONSE_SIZE];
        let credential_identifier = account_id(0x37);
        let mut upload = [0xa5_u8; OPAQUE_REGISTRATION_UPLOAD_SIZE];
        let mut upload_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_finish(
                    handle,
                    password.as_ptr(),
                    password.len(),
                    response.as_ptr(),
                    response.len(),
                    credential_identifier.as_ptr(),
                    credential_identifier.len(),
                    upload.as_mut_ptr(),
                    upload.len() - 1,
                    &mut upload_length,
                )
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        assert_eq!(upload_length, 0);
        assert!(upload.iter().all(|value| *value == 0xa5));
        assert_eq!(
            kelivo_opaque_client_state_close(handle),
            KelivoStatus::InvalidOpaqueStateHandle.code()
        );
    }

    #[test]
    fn opaque_finish_accepts_only_raw_uuid_v4_account_ids() {
        let _finish_test_guard = opaque_finish_test_guard();
        let password = b"registration-password";
        let mut handle = INVALID_OPAQUE_STATE_HANDLE;
        let mut request_length = 0_usize;
        let mut request = [0_u8; OPAQUE_REGISTRATION_REQUEST_SIZE];
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_start(
                    password.as_ptr(),
                    password.len(),
                    &mut handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::Ok.code()
        );

        let response = [0_u8; OPAQUE_REGISTRATION_RESPONSE_SIZE];
        let invalid_account_id = [0_u8; OPAQUE_ACCOUNT_ID_SIZE];
        let mut upload = [0xa5_u8; OPAQUE_REGISTRATION_UPLOAD_SIZE];
        let mut upload_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_finish(
                    handle,
                    password.as_ptr(),
                    password.len(),
                    response.as_ptr(),
                    response.len(),
                    invalid_account_id.as_ptr(),
                    invalid_account_id.len(),
                    upload.as_mut_ptr(),
                    upload.len(),
                    &mut upload_length,
                )
            },
            KelivoStatus::InvalidAccountId.code()
        );
        assert_eq!(upload_length, 0);
        assert!(upload.iter().all(|value| *value == 0xa5));
        assert_eq!(
            kelivo_opaque_client_state_close(handle),
            KelivoStatus::InvalidOpaqueStateHandle.code()
        );
    }

    #[test]
    fn opaque_state_type_confusion_fails_closed_and_consumes_handle() {
        let _finish_test_guard = opaque_finish_test_guard();
        let password = b"login-password";
        let credential_identifier = account_id(0x47);
        let mut login_handle = INVALID_OPAQUE_STATE_HANDLE;
        let mut request = [0_u8; OPAQUE_CREDENTIAL_REQUEST_SIZE];
        let mut request_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_login_start(
                    password.as_ptr(),
                    password.len(),
                    &mut login_handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::Ok.code()
        );

        let response = [0_u8; OPAQUE_REGISTRATION_RESPONSE_SIZE];
        let mut upload = [0xa5_u8; OPAQUE_REGISTRATION_UPLOAD_SIZE];
        let mut upload_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_registration_finish(
                    login_handle,
                    password.as_ptr(),
                    password.len(),
                    response.as_ptr(),
                    response.len(),
                    credential_identifier.as_ptr(),
                    credential_identifier.len(),
                    upload.as_mut_ptr(),
                    upload.len(),
                    &mut upload_length,
                )
            },
            KelivoStatus::InvalidOpaqueStateHandle.code()
        );
        assert_eq!(upload_length, 0);
        assert_eq!(
            kelivo_opaque_client_state_close(login_handle),
            KelivoStatus::InvalidOpaqueStateHandle.code()
        );
    }

    #[test]
    fn opaque_login_finish_authenticates_server_without_exporting_session_key() {
        let _finish_test_guard = opaque_finish_test_guard();
        let password = b"login-password";
        let credential_identifier = account_id(0x57);
        let binding = kelivo_secure_core_protocol::AccountBinding::new(&credential_identifier)
            .expect("账户绑定应有效");
        let mut server_rng = kelivo_secure_core_protocol::system_rng().expect("服务端随机源应可用");
        let setup = kelivo_secure_core_protocol::generate_server_setup(&mut server_rng)
            .expect("服务端配置应生成");

        let mut registration_rng =
            kelivo_secure_core_protocol::system_rng().expect("客户端随机源应可用");
        let (registration_state, registration_request) =
            kelivo_secure_core_protocol::client_registration_start(&mut registration_rng, password)
                .expect("客户端注册应开始")
                .into_parts();
        let registration_response = kelivo_secure_core_protocol::server_registration_start(
            &setup,
            registration_request,
            binding,
        )
        .expect("服务端注册响应应生成");
        let registration_upload = kelivo_secure_core_protocol::client_registration_finish(
            &mut registration_rng,
            registration_state,
            password,
            registration_response,
            binding,
        )
        .expect("客户端注册应完成")
        .into_upload();
        let registration =
            kelivo_secure_core_protocol::server_registration_finish(registration_upload)
                .expect("服务端注册应完成");

        let mut login_handle = INVALID_OPAQUE_STATE_HANDLE;
        let mut request = [0_u8; OPAQUE_CREDENTIAL_REQUEST_SIZE];
        let mut request_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_login_start(
                    password.as_ptr(),
                    password.len(),
                    &mut login_handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(request_length, request.len());

        let server_login = kelivo_secure_core_protocol::server_login_start(
            &mut server_rng,
            &setup,
            Some(&registration),
            kelivo_secure_core_protocol::CredentialRequest::from_bytes(&request)
                .expect("登录请求应可解析"),
            binding,
        )
        .expect("服务端登录响应应生成");
        let mut finalization = [0_u8; OPAQUE_CREDENTIAL_FINALIZATION_SIZE];
        let mut finalization_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_login_finish(
                    login_handle,
                    password.as_ptr(),
                    password.len(),
                    server_login.response.as_bytes().as_ptr(),
                    server_login.response.as_bytes().len(),
                    credential_identifier.as_ptr(),
                    credential_identifier.len(),
                    finalization.as_mut_ptr(),
                    finalization.len(),
                    &mut finalization_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(finalization_length, finalization.len());
        kelivo_secure_core_protocol::server_login_finish(
            server_login.state,
            kelivo_secure_core_protocol::CredentialFinalization::from_bytes(&finalization)
                .expect("客户端完成消息应可解析"),
            binding,
        )
        .expect("服务端必须确认客户端认证成功");
        assert_eq!(
            kelivo_opaque_client_state_close(login_handle),
            KelivoStatus::InvalidOpaqueStateHandle.code()
        );
    }

    #[test]
    fn opaque_login_finish_rejects_malformed_response_and_consumes_state() {
        let _finish_test_guard = opaque_finish_test_guard();
        let password = b"login-password";
        let credential_identifier = account_id(0x67);
        let mut login_handle = INVALID_OPAQUE_STATE_HANDLE;
        let mut request = [0_u8; OPAQUE_CREDENTIAL_REQUEST_SIZE];
        let mut request_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_login_start(
                    password.as_ptr(),
                    password.len(),
                    &mut login_handle,
                    request.as_mut_ptr(),
                    request.len(),
                    &mut request_length,
                )
            },
            KelivoStatus::Ok.code()
        );

        let response = [0_u8; OPAQUE_CREDENTIAL_RESPONSE_SIZE];
        let mut finalization = [0xa5_u8; OPAQUE_CREDENTIAL_FINALIZATION_SIZE];
        let mut finalization_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_opaque_client_login_finish(
                    login_handle,
                    password.as_ptr(),
                    password.len(),
                    response.as_ptr(),
                    response.len(),
                    credential_identifier.as_ptr(),
                    credential_identifier.len(),
                    finalization.as_mut_ptr(),
                    finalization.len(),
                    &mut finalization_length,
                )
            },
            KelivoStatus::OpaqueMessageInvalid.code()
        );
        assert_eq!(finalization_length, 0);
        assert!(finalization.iter().all(|value| *value == 0xa5));
        assert_eq!(
            kelivo_opaque_client_state_close(login_handle),
            KelivoStatus::InvalidOpaqueStateHandle.code()
        );
    }

    fn generate_device_identity() -> u64 {
        let mut handle = INVALID_KEY_HANDLE;
        assert_eq!(
            unsafe { kelivo_device_identity_generate(&mut handle) },
            KelivoStatus::Ok.code()
        );
        assert!(handle_has_tag(handle, DEVICE_IDENTITY_HANDLE_TAG));
        handle
    }

    fn generate_ark(user_id: &[u8; OPAQUE_ACCOUNT_ID_SIZE], key_epoch: u32) -> u64 {
        let mut handle = INVALID_KEY_HANDLE;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_generate(
                    user_id.as_ptr(),
                    user_id.len(),
                    key_epoch,
                    &mut handle,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert!(handle_has_tag(handle, ACCOUNT_ROOT_KEY_HANDLE_TAG));
        handle
    }

    fn account_trust_public_key(
        ark_handle: u64,
        user_id: &[u8; OPAQUE_ACCOUNT_ID_SIZE],
        key_epoch: u32,
    ) -> [u8; device_core::ACCOUNT_TRUST_PUBLIC_KEY_LENGTH] {
        let mut public_key = [0_u8; device_core::ACCOUNT_TRUST_PUBLIC_KEY_LENGTH];
        let mut public_key_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_account_trust_public_key_derive(
                    ark_handle,
                    user_id.as_ptr(),
                    user_id.len(),
                    key_epoch,
                    public_key.as_mut_ptr(),
                    public_key.len(),
                    &mut public_key_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(public_key_length, public_key.len());
        public_key
    }

    fn account_trust_signature(
        ark_handle: u64,
        user_id: &[u8; OPAQUE_ACCOUNT_ID_SIZE],
        key_epoch: u32,
        payload: &[u8],
    ) -> [u8; device_core::ACCOUNT_TRUST_SIGNATURE_LENGTH] {
        let mut signature = [0_u8; device_core::ACCOUNT_TRUST_SIGNATURE_LENGTH];
        let mut signature_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_sign(
                    ark_handle,
                    user_id.as_ptr(),
                    user_id.len(),
                    key_epoch,
                    payload.as_ptr(),
                    payload.len(),
                    signature.as_mut_ptr(),
                    signature.len(),
                    &mut signature_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(signature_length, signature.len());
        signature
    }

    #[test]
    fn account_trust_abi_is_epoch_exact_strict_and_zeroes_failed_outputs() {
        let user_id = account_id(0x61);
        let other_user_id = account_id(0x62);
        let canonical_payload = b"canonical-member-set-v1";
        let keyring = generate_ark(&user_id, 7);
        let epoch_eight = generate_ark(&user_id, 8);
        assert_eq!(
            kelivo_account_root_keyring_add_epoch(keyring, epoch_eight),
            KelivoStatus::Ok.code()
        );

        let public_key = account_trust_public_key(keyring, &user_id, 7);
        assert_eq!(account_trust_public_key(keyring, &user_id, 7), public_key);
        let epoch_eight_public_key = account_trust_public_key(keyring, &user_id, 8);
        assert_ne!(epoch_eight_public_key, public_key);
        let signature = account_trust_signature(keyring, &user_id, 7, canonical_payload);
        assert_eq!(
            account_trust_signature(keyring, &user_id, 7, canonical_payload),
            signature
        );

        let mut cross_account_public_key = [0xa5_u8; device_core::ACCOUNT_TRUST_PUBLIC_KEY_LENGTH];
        let mut cross_account_public_key_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_trust_public_key_derive(
                    keyring,
                    other_user_id.as_ptr(),
                    other_user_id.len(),
                    7,
                    cross_account_public_key.as_mut_ptr(),
                    cross_account_public_key.len(),
                    &mut cross_account_public_key_length,
                )
            },
            KelivoStatus::DeviceAuthenticationFailed.code()
        );
        assert_eq!(cross_account_public_key_length, 0);
        assert!(cross_account_public_key.iter().all(|byte| *byte == 0));

        let mut cross_account_signature = [0xa5_u8; device_core::ACCOUNT_TRUST_SIGNATURE_LENGTH];
        let mut cross_account_signature_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_sign(
                    keyring,
                    other_user_id.as_ptr(),
                    other_user_id.len(),
                    7,
                    canonical_payload.as_ptr(),
                    canonical_payload.len(),
                    cross_account_signature.as_mut_ptr(),
                    cross_account_signature.len(),
                    &mut cross_account_signature_length,
                )
            },
            KelivoStatus::DeviceAuthenticationFailed.code()
        );
        assert_eq!(cross_account_signature_length, 0);
        assert!(cross_account_signature.iter().all(|byte| *byte == 0));

        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_verify(
                    public_key.as_ptr(),
                    public_key.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    7,
                    canonical_payload.as_ptr(),
                    canonical_payload.len(),
                    signature.as_ptr(),
                    signature.len(),
                )
            },
            KelivoStatus::Ok.code()
        );

        for (verification_user, verification_payload, verification_key) in [
            (&other_user_id, canonical_payload.as_slice(), &public_key),
            (&user_id, b"changed-member-set-v1".as_slice(), &public_key),
            (
                &user_id,
                canonical_payload.as_slice(),
                &epoch_eight_public_key,
            ),
        ] {
            assert_eq!(
                unsafe {
                    kelivo_account_trust_payload_verify(
                        verification_key.as_ptr(),
                        verification_key.len(),
                        verification_user.as_ptr(),
                        verification_user.len(),
                        7,
                        verification_payload.as_ptr(),
                        verification_payload.len(),
                        signature.as_ptr(),
                        signature.len(),
                    )
                },
                KelivoStatus::DeviceAuthenticationFailed.code()
            );
        }

        let mut tampered_signature = signature;
        tampered_signature[device_core::ACCOUNT_TRUST_SIGNATURE_LENGTH - 1] ^= 1;
        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_verify(
                    public_key.as_ptr(),
                    public_key.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    7,
                    canonical_payload.as_ptr(),
                    canonical_payload.len(),
                    tampered_signature.as_ptr(),
                    tampered_signature.len(),
                )
            },
            KelivoStatus::DeviceAuthenticationFailed.code()
        );
        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_verify(
                    [0_u8; device_core::ACCOUNT_TRUST_PUBLIC_KEY_LENGTH].as_ptr(),
                    device_core::ACCOUNT_TRUST_PUBLIC_KEY_LENGTH,
                    user_id.as_ptr(),
                    user_id.len(),
                    7,
                    canonical_payload.as_ptr(),
                    canonical_payload.len(),
                    signature.as_ptr(),
                    signature.len(),
                )
            },
            KelivoStatus::DeviceMessageInvalid.code()
        );
        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_verify(
                    public_key.as_ptr(),
                    public_key.len() - 1,
                    user_id.as_ptr(),
                    user_id.len(),
                    7,
                    canonical_payload.as_ptr(),
                    canonical_payload.len(),
                    signature.as_ptr(),
                    signature.len(),
                )
            },
            KelivoStatus::DeviceMessageInvalid.code()
        );
        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_verify(
                    public_key.as_ptr(),
                    public_key.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    7,
                    canonical_payload.as_ptr(),
                    canonical_payload.len(),
                    signature.as_ptr(),
                    signature.len() - 1,
                )
            },
            KelivoStatus::DeviceMessageInvalid.code()
        );

        let mut failed_public_key = [0xa5_u8; device_core::ACCOUNT_TRUST_PUBLIC_KEY_LENGTH];
        let mut failed_public_key_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_trust_public_key_derive(
                    keyring,
                    user_id.as_ptr(),
                    user_id.len(),
                    0,
                    failed_public_key.as_mut_ptr(),
                    failed_public_key.len(),
                    &mut failed_public_key_length,
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(failed_public_key_length, 0);
        assert!(failed_public_key.iter().all(|byte| *byte == 0));
        failed_public_key.fill(0xa5);
        assert_eq!(
            unsafe {
                kelivo_account_trust_public_key_derive(
                    keyring,
                    user_id.as_ptr(),
                    user_id.len(),
                    9,
                    failed_public_key.as_mut_ptr(),
                    failed_public_key.len(),
                    &mut failed_public_key_length,
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(failed_public_key_length, 0);
        assert!(failed_public_key.iter().all(|byte| *byte == 0));

        let mut short_public_key = [0xa5_u8; device_core::ACCOUNT_TRUST_PUBLIC_KEY_LENGTH - 1];
        let mut required_public_key_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_account_trust_public_key_derive(
                    keyring,
                    user_id.as_ptr(),
                    user_id.len(),
                    7,
                    short_public_key.as_mut_ptr(),
                    short_public_key.len(),
                    &mut required_public_key_length,
                )
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        assert_eq!(
            required_public_key_length,
            device_core::ACCOUNT_TRUST_PUBLIC_KEY_LENGTH
        );
        assert!(short_public_key.iter().all(|byte| *byte == 0));

        let mut failed_signature = [0xa5_u8; device_core::ACCOUNT_TRUST_SIGNATURE_LENGTH];
        let mut failed_signature_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_sign(
                    keyring,
                    user_id.as_ptr(),
                    user_id.len(),
                    7,
                    ptr::null(),
                    0,
                    failed_signature.as_mut_ptr(),
                    failed_signature.len(),
                    &mut failed_signature_length,
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(failed_signature_length, 0);
        assert!(failed_signature.iter().all(|byte| *byte == 0));
        let oversized_payload = vec![0x63; device_core::ACCOUNT_TRUST_PAYLOAD_MAX_LENGTH + 1];
        failed_signature.fill(0xa5);
        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_sign(
                    keyring,
                    user_id.as_ptr(),
                    user_id.len(),
                    7,
                    oversized_payload.as_ptr(),
                    oversized_payload.len(),
                    failed_signature.as_mut_ptr(),
                    failed_signature.len(),
                    &mut failed_signature_length,
                )
            },
            KelivoStatus::InputTooLarge.code()
        );
        assert_eq!(failed_signature_length, 0);
        assert!(failed_signature.iter().all(|byte| *byte == 0));

        let maximum_payload = vec![0x64; device_core::ACCOUNT_TRUST_PAYLOAD_MAX_LENGTH];
        let maximum_signature = account_trust_signature(keyring, &user_id, 8, &maximum_payload);
        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_verify(
                    epoch_eight_public_key.as_ptr(),
                    epoch_eight_public_key.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    8,
                    maximum_payload.as_ptr(),
                    maximum_payload.len(),
                    maximum_signature.as_ptr(),
                    maximum_signature.len(),
                )
            },
            KelivoStatus::Ok.code()
        );

        assert_eq!(
            kelivo_account_root_keyring_prune_epoch(keyring, 7),
            KelivoStatus::Ok.code()
        );
        failed_public_key.fill(0xa5);
        assert_eq!(
            unsafe {
                kelivo_account_trust_public_key_derive(
                    keyring,
                    user_id.as_ptr(),
                    user_id.len(),
                    7,
                    failed_public_key.as_mut_ptr(),
                    failed_public_key.len(),
                    &mut failed_public_key_length,
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert!(failed_public_key.iter().all(|byte| *byte == 0));

        let identity = generate_device_identity();
        failed_public_key.fill(0xa5);
        assert_eq!(
            unsafe {
                kelivo_account_trust_public_key_derive(
                    identity,
                    user_id.as_ptr(),
                    user_id.len(),
                    8,
                    failed_public_key.as_mut_ptr(),
                    failed_public_key.len(),
                    &mut failed_public_key_length,
                )
            },
            KelivoStatus::InvalidAccountRootKeyHandle.code()
        );
        assert!(failed_public_key.iter().all(|byte| *byte == 0));
        assert_eq!(
            kelivo_device_identity_handle_close(identity),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(keyring),
            KelivoStatus::Ok.code()
        );
        failed_signature.fill(0xa5);
        assert_eq!(
            unsafe {
                kelivo_account_trust_payload_sign(
                    keyring,
                    user_id.as_ptr(),
                    user_id.len(),
                    8,
                    canonical_payload.as_ptr(),
                    canonical_payload.len(),
                    failed_signature.as_mut_ptr(),
                    failed_signature.len(),
                    &mut failed_signature_length,
                )
            },
            KelivoStatus::InvalidAccountRootKeyHandle.code()
        );
        assert!(failed_signature.iter().all(|byte| *byte == 0));
        assert_eq!(
            kelivo_account_root_key_handle_close(epoch_eight),
            KelivoStatus::Ok.code()
        );
    }

    #[test]
    fn account_record_id_derivation_enforces_keyed_uuid_contract() {
        let user_id = account_id(0x31);
        let ark = generate_ark(&user_id, 1);
        let canonical_key = b"chat-message/018f2f89-8d5a-7bd2-a459-5d540a8f90ab";
        let mut first = [0_u8; 16];
        let mut first_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    ark,
                    canonical_key.as_ptr(),
                    canonical_key.len(),
                    1,
                    first.as_mut_ptr(),
                    first.len(),
                    &mut first_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(first_length, first.len());
        assert_eq!(first[6] & 0xf0, 0x40);
        assert_eq!(first[8] & 0xc0, 0x80);

        let mut repeated = [0_u8; 16];
        let mut repeated_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    ark,
                    canonical_key.as_ptr(),
                    canonical_key.len(),
                    1,
                    repeated.as_mut_ptr(),
                    repeated.len(),
                    &mut repeated_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(repeated, first);

        let other_key = b"chat-message/018f2f89-8d5a-7bd2-a459-5d540a8f90ac";
        let mut other = [0_u8; 16];
        let mut other_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    ark,
                    other_key.as_ptr(),
                    other_key.len(),
                    1,
                    other.as_mut_ptr(),
                    other.len(),
                    &mut other_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_ne!(other, first);

        let maximum_key = [0x5a_u8; device_core::RECORD_ENTITY_KEY_MAX_LENGTH];
        let mut boundary_output = [0_u8; 16];
        let mut boundary_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    ark,
                    maximum_key.as_ptr(),
                    maximum_key.len(),
                    1,
                    boundary_output.as_mut_ptr(),
                    boundary_output.len(),
                    &mut boundary_length,
                )
            },
            KelivoStatus::Ok.code()
        );

        let mut untouched = [0xa5_u8; 15];
        let mut required_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    ark,
                    canonical_key.as_ptr(),
                    canonical_key.len(),
                    1,
                    untouched.as_mut_ptr(),
                    untouched.len(),
                    &mut required_length,
                )
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        assert_eq!(required_length, 16);
        assert!(untouched.iter().all(|value| *value == 0xa5));

        let mut rejected_output = [0xa5_u8; 16];
        let mut rejected_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    ark,
                    ptr::null(),
                    0,
                    1,
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(rejected_length, 0);
        assert!(rejected_output.iter().all(|value| *value == 0xa5));

        let oversized_key = [0x5a_u8; device_core::RECORD_ENTITY_KEY_MAX_LENGTH + 1];
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    ark,
                    oversized_key.as_ptr(),
                    oversized_key.len(),
                    1,
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::InputTooLarge.code()
        );
        assert_eq!(rejected_length, 0);

        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    ark,
                    canonical_key.as_ptr(),
                    canonical_key.len(),
                    0,
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(rejected_length, 0);
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    ark,
                    canonical_key.as_ptr(),
                    canonical_key.len(),
                    2,
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(rejected_length, 0);

        assert_eq!(
            kelivo_account_root_key_handle_close(ark),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    ark,
                    canonical_key.as_ptr(),
                    canonical_key.len(),
                    1,
                    rejected_output.as_mut_ptr(),
                    rejected_output.len(),
                    &mut rejected_length,
                )
            },
            KelivoStatus::InvalidAccountRootKeyHandle.code()
        );
        assert_eq!(rejected_length, 0);
    }

    fn device_public_keys(handle: u64) -> [u8; device_core::DEVICE_PUBLIC_KEYS_LENGTH] {
        let mut public_keys = [0_u8; device_core::DEVICE_PUBLIC_KEYS_LENGTH];
        let mut public_keys_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_identity_public_keys(
                    handle,
                    public_keys.as_mut_ptr(),
                    public_keys.len(),
                    &mut public_keys_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(public_keys_length, public_keys.len());
        public_keys
    }

    #[test]
    fn external_device_public_keys_require_strict_validation() {
        let identity = generate_device_identity();
        let public_keys = device_public_keys(identity);
        let signing = &public_keys[..crypto::DEVICE_PUBLIC_KEY_LENGTH];
        let agreement = &public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..];

        assert_eq!(
            unsafe { kelivo_device_signing_public_key_validate(signing.as_ptr(), signing.len()) },
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            unsafe {
                kelivo_device_key_agreement_public_key_validate(agreement.as_ptr(), agreement.len())
            },
            KelivoStatus::Ok.code()
        );

        let invalid = [0_u8; crypto::DEVICE_PUBLIC_KEY_LENGTH];
        assert_eq!(
            unsafe { kelivo_device_signing_public_key_validate(invalid.as_ptr(), invalid.len()) },
            KelivoStatus::DeviceMessageInvalid.code()
        );
        assert_eq!(
            unsafe {
                kelivo_device_key_agreement_public_key_validate(invalid.as_ptr(), invalid.len())
            },
            KelivoStatus::DeviceMessageInvalid.code()
        );
        assert_eq!(
            unsafe {
                kelivo_device_signing_public_key_validate(signing.as_ptr(), signing.len() - 1)
            },
            KelivoStatus::DeviceMessageInvalid.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(identity),
            KelivoStatus::Ok.code()
        );
    }

    #[test]
    fn device_and_ark_handles_are_strongly_typed_and_close_once() {
        let identity = generate_device_identity();
        let user_id = account_id(0x32);
        let ark = generate_ark(&user_id, 1);
        let public_keys = device_public_keys(identity);
        assert!(public_keys.iter().any(|byte| *byte != 0));

        assert_eq!(
            kelivo_account_root_key_handle_close(identity),
            KelivoStatus::InvalidAccountRootKeyHandle.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(ark),
            KelivoStatus::InvalidDeviceIdentityHandle.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(identity),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(identity),
            KelivoStatus::InvalidDeviceIdentityHandle.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(ark),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(ark),
            KelivoStatus::InvalidAccountRootKeyHandle.code()
        );
    }

    #[test]
    fn ark_keyring_abi_enforces_exact_epoch_capacity_and_atomic_mutation() {
        let user_id = account_id(0x33);
        let other_user_id = account_id(0x34);
        let mut rejected = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_generate(user_id.as_ptr(), user_id.len(), 0, &mut rejected)
            },
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(rejected, INVALID_KEY_HANDLE);

        let invalid_user_id = [0_u8; OPAQUE_ACCOUNT_ID_SIZE];
        rejected = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_generate(
                    invalid_user_id.as_ptr(),
                    invalid_user_id.len(),
                    1,
                    &mut rejected,
                )
            },
            KelivoStatus::DeviceMessageInvalid.code()
        );
        assert_eq!(rejected, INVALID_KEY_HANDLE);

        let target = generate_ark(&user_id, 1);
        let epoch_two = generate_ark(&user_id, 2);
        assert_eq!(
            kelivo_account_root_keyring_add_epoch(target, epoch_two),
            KelivoStatus::Ok.code()
        );
        assert!(device_core::ark_for_handle(target, 1).is_ok());
        assert!(device_core::ark_for_handle(target, 2).is_ok());
        assert_eq!(
            kelivo_account_root_keyring_add_epoch(target, epoch_two),
            KelivoStatus::InvalidArgument.code()
        );

        let duplicate_or_older = generate_ark(&user_id, 1);
        assert_eq!(
            kelivo_account_root_keyring_add_epoch(target, duplicate_or_older),
            KelivoStatus::InvalidArgument.code()
        );

        let mut added_sources = Vec::new();
        for epoch in 3..=crypto::ACCOUNT_ROOT_KEYRING_CAPACITY as u32 {
            let source = generate_ark(&user_id, epoch);
            assert_eq!(
                kelivo_account_root_keyring_add_epoch(target, source),
                KelivoStatus::Ok.code()
            );
            added_sources.push(source);
        }
        let over_capacity =
            generate_ark(&user_id, crypto::ACCOUNT_ROOT_KEYRING_CAPACITY as u32 + 1);
        assert_eq!(
            kelivo_account_root_keyring_add_epoch(target, over_capacity),
            KelivoStatus::InvalidArgument.code()
        );
        assert!(
            device_core::ark_for_handle(target, crypto::ACCOUNT_ROOT_KEYRING_CAPACITY as u32 + 1,)
                .is_err()
        );

        assert_eq!(
            kelivo_account_root_keyring_prune_epoch(
                target,
                crypto::ACCOUNT_ROOT_KEYRING_CAPACITY as u32,
            ),
            KelivoStatus::InvalidArgument.code()
        );
        assert_eq!(
            kelivo_account_root_keyring_prune_epoch(target, 2),
            KelivoStatus::Ok.code()
        );
        assert!(device_core::ark_for_handle(target, 2).is_err());
        assert_eq!(
            kelivo_account_root_keyring_prune_epoch(target, 2),
            KelivoStatus::InvalidArgument.code()
        );

        let cross_account_source = generate_ark(&other_user_id, 9);
        assert_eq!(
            kelivo_account_root_keyring_add_epoch(target, cross_account_source),
            KelivoStatus::DeviceAuthenticationFailed.code()
        );
        assert!(device_core::ark_for_handle(target, 9).is_err());

        let closed_source = generate_ark(&user_id, 9);
        assert_eq!(
            kelivo_account_root_key_handle_close(closed_source),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_keyring_add_epoch(target, closed_source),
            KelivoStatus::InvalidAccountRootKeyHandle.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(target),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_keyring_prune_epoch(target, 1),
            KelivoStatus::InvalidAccountRootKeyHandle.code()
        );
        assert_eq!(
            kelivo_account_root_keyring_add_epoch(target, epoch_two),
            KelivoStatus::InvalidAccountRootKeyHandle.code()
        );

        for source in added_sources {
            assert_eq!(
                kelivo_account_root_key_handle_close(source),
                KelivoStatus::Ok.code()
            );
        }
        assert_eq!(
            kelivo_account_root_key_handle_close(over_capacity),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(cross_account_source),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(duplicate_or_older),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(epoch_two),
            KelivoStatus::Ok.code()
        );
    }

    #[test]
    fn registration_and_login_proofs_hash_only_strict_raw_payloads_in_rust() {
        let identity = generate_device_identity();
        let user_id = account_id(0x41);
        let ark = generate_ark(&user_id, 1);
        let public_keys = device_public_keys(identity);
        let signing_public_key = crypto::DeviceSigningPublicKey::from_bytes(
            public_keys[..crypto::DEVICE_PUBLIC_KEY_LENGTH]
                .try_into()
                .expect("Ed25519 公钥长度固定"),
        )
        .expect("Ed25519 公钥应有效");
        let key_agreement_public_key = crypto::DeviceKeyAgreementPublicKey::from_bytes(
            public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..]
                .try_into()
                .expect("X25519 公钥长度固定"),
        )
        .expect("X25519 公钥应有效");
        let device_id = account_id(0x42);
        let attempt_id = account_id(0x43);
        let account_context_id = account_id(0x44);
        let challenge = [0x45; crypto::DEVICE_PROOF_CHALLENGE_LENGTH];
        let expires_at_ms = 1_800_000_000_000_u64;
        let key_epoch = 1_u32;
        let registration_upload = [0x46; OPAQUE_REGISTRATION_UPLOAD_SIZE];
        let mut bundle = [0_u8; device_core::REGISTRATION_FINISH_BUNDLE_LENGTH];
        let mut bundle_length = usize::MAX;

        assert_eq!(
            unsafe {
                kelivo_device_registration_finish_create(
                    identity,
                    ark,
                    user_id.as_ptr(),
                    user_id.len(),
                    device_id.as_ptr(),
                    device_id.len(),
                    key_epoch,
                    attempt_id.as_ptr(),
                    attempt_id.len(),
                    account_context_id.as_ptr(),
                    account_context_id.len(),
                    expires_at_ms,
                    challenge.as_ptr(),
                    challenge.len(),
                    registration_upload.as_ptr(),
                    registration_upload.len(),
                    bundle.as_mut_ptr(),
                    bundle.len(),
                    &mut bundle_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(bundle_length, bundle.len());
        let envelope = crypto::ArkEnvelope::from_bytes(&bundle[..crypto::ARK_ENVELOPE_LENGTH])
            .expect("注册 KAEK 应是严格线格式");
        let user_id = crypto::UserId::new(user_id).expect("用户 UUID 应有效");
        let device_id = crypto::DeviceId::new(device_id).expect("设备 UUID 应有效");
        crypto::verify_ark_envelope(
            &envelope,
            crypto::ArkEnvelopeBinding {
                user_id,
                issuer_device_id: device_id,
                target_device_id: device_id,
                key_epoch,
                issuer_signing_public_key: signing_public_key,
                issuer_key_agreement_public_key: key_agreement_public_key,
                target_signing_public_key: signing_public_key,
                target_key_agreement_public_key: key_agreement_public_key,
            },
        )
        .expect("注册自信封必须由同一设备身份签发");
        let proof_signature =
            crypto::DeviceProofSignature::from_bytes(&bundle[crypto::ARK_ENVELOPE_LENGTH..])
                .expect("注册证明签名长度固定");
        let registration_fields = crypto::DeviceProofFields {
            kind: crypto::DeviceProofKind::RegistrationFinish,
            attempt_id: crypto::DeviceProofAttemptId::new(attempt_id).expect("attempt UUID 应有效"),
            account_context_id: crypto::AccountContextId::new(account_context_id)
                .expect("账户上下文 UUID 应有效"),
            device_id,
            expires_at_ms,
            challenge: crypto::DeviceProofChallenge::from_bytes(challenge),
            signing_public_key,
            key_agreement_public_key,
            primary_payload_hash: crypto::Sha256Digest::of(&registration_upload),
            envelope_hash: crypto::Sha256Digest::of(envelope.as_bytes()),
        };
        crypto::DeviceProofMessage::new(registration_fields)
            .expect("注册 KDPF 应可构造")
            .verify_expected(registration_fields, &proof_signature)
            .expect("注册证明必须覆盖原始 upload 与同次生成的 KAEK");

        let finalization = [0x47; OPAQUE_CREDENTIAL_FINALIZATION_SIZE];
        let mut login_signature = [0_u8; crypto::DEVICE_PROOF_SIGNATURE_LENGTH];
        let mut login_signature_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_login_proof_sign(
                    identity,
                    attempt_id.as_ptr(),
                    attempt_id.len(),
                    account_context_id.as_ptr(),
                    account_context_id.len(),
                    device_id.as_bytes().as_ptr(),
                    device_id.as_bytes().len(),
                    expires_at_ms,
                    challenge.as_ptr(),
                    challenge.len(),
                    finalization.as_ptr(),
                    finalization.len(),
                    login_signature.as_mut_ptr(),
                    login_signature.len(),
                    &mut login_signature_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(login_signature_length, login_signature.len());
        let login_fields = crypto::DeviceProofFields {
            kind: crypto::DeviceProofKind::LoginFinish,
            attempt_id: crypto::DeviceProofAttemptId::new(attempt_id).expect("attempt UUID 应有效"),
            account_context_id: crypto::AccountContextId::new(account_context_id)
                .expect("账户上下文 UUID 应有效"),
            device_id,
            expires_at_ms,
            challenge: crypto::DeviceProofChallenge::from_bytes(challenge),
            signing_public_key,
            key_agreement_public_key,
            primary_payload_hash: crypto::Sha256Digest::of(&finalization),
            envelope_hash: crypto::Sha256Digest::of(&[]),
        };
        crypto::DeviceProofMessage::new(login_fields)
            .expect("登录 KDPF 应可构造")
            .verify_expected(
                login_fields,
                &crypto::DeviceProofSignature::from_bytes(&login_signature)
                    .expect("登录签名长度固定"),
            )
            .expect("登录证明必须覆盖原始 finalization");

        assert_eq!(
            kelivo_account_root_key_handle_close(ark),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(identity),
            KelivoStatus::Ok.code()
        );
    }

    #[test]
    fn pending_state_pairing_accept_and_full_state_form_one_closed_loop() {
        let key_handle = register_key(Zeroizing::new(
            vec![0x91; LOCAL_KEY_SIZE].into_boxed_slice(),
        ))
        .expect("测试槽位主密钥应注册");
        let issuer_identity = generate_device_identity();
        let target_identity = generate_device_identity();
        let target_device_id = account_id(0x31);
        let issuer_device_id = account_id(0x32);
        let user_id = account_id(0x33);
        let issuer_ark = generate_ark(&user_id, 7);
        let challenge = [0x35; crypto::DEVICE_PROOF_CHALLENGE_LENGTH];
        let now_ms = 1_800_000_000_000_u64;
        let expires_at_ms = now_ms + 300_000;
        let key_epoch = 7_u32;
        let key_version = 1_u32;

        let mut pending_blob = [0_u8; device_core::DEVICE_STATE_BLOB_LENGTH];
        let mut pending_blob_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_state_seal(
                    key_handle,
                    target_identity,
                    INVALID_KEY_HANDLE,
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    key_version,
                    ptr::null(),
                    0,
                    0,
                    pending_blob.as_mut_ptr(),
                    pending_blob.len(),
                    &mut pending_blob_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(pending_blob_length, pending_blob.len());
        assert_eq!(
            kelivo_device_identity_handle_close(target_identity),
            KelivoStatus::Ok.code()
        );

        let mut rejected_identity = u64::MAX;
        let mut rejected_ark = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    pending_blob.as_ptr(),
                    pending_blob.len(),
                    ptr::null_mut(),
                    &mut rejected_identity,
                    &mut rejected_ark,
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(rejected_identity, INVALID_KEY_HANDLE);
        assert_eq!(rejected_ark, INVALID_KEY_HANDLE);

        let mut rejected_binding = sentinel_device_state_binding();
        rejected_ark = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    pending_blob.as_ptr(),
                    pending_blob.len(),
                    &mut rejected_binding,
                    ptr::null_mut(),
                    &mut rejected_ark,
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(rejected_binding, KelivoDeviceStateBinding::default());
        assert_eq!(rejected_ark, INVALID_KEY_HANDLE);

        rejected_binding = sentinel_device_state_binding();
        rejected_identity = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    pending_blob.as_ptr(),
                    pending_blob.len(),
                    &mut rejected_binding,
                    &mut rejected_identity,
                    ptr::null_mut(),
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(rejected_binding, KelivoDeviceStateBinding::default());
        assert_eq!(rejected_identity, INVALID_KEY_HANDLE);

        rejected_binding = sentinel_device_state_binding();
        rejected_identity = u64::MAX;
        rejected_ark = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    ptr::null(),
                    pending_blob.len(),
                    &mut rejected_binding,
                    &mut rejected_identity,
                    &mut rejected_ark,
                )
            },
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(rejected_binding, KelivoDeviceStateBinding::default());
        assert_eq!(rejected_identity, INVALID_KEY_HANDLE);
        assert_eq!(rejected_ark, INVALID_KEY_HANDLE);

        rejected_binding = sentinel_device_state_binding();
        rejected_identity = u64::MAX;
        rejected_ark = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    pending_blob.as_ptr(),
                    pending_blob.len() - 1,
                    &mut rejected_binding,
                    &mut rejected_identity,
                    &mut rejected_ark,
                )
            },
            KelivoStatus::DeviceStateInvalid.code()
        );
        assert_eq!(rejected_binding, KelivoDeviceStateBinding::default());
        assert_eq!(rejected_identity, INVALID_KEY_HANDLE);
        assert_eq!(rejected_ark, INVALID_KEY_HANDLE);

        let legacy_v1_blob = [0_u8; 188];
        rejected_binding = sentinel_device_state_binding();
        rejected_identity = u64::MAX;
        rejected_ark = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    legacy_v1_blob.as_ptr(),
                    legacy_v1_blob.len(),
                    &mut rejected_binding,
                    &mut rejected_identity,
                    &mut rejected_ark,
                )
            },
            KelivoStatus::DeviceStateInvalid.code()
        );
        assert_eq!(rejected_binding, KelivoDeviceStateBinding::default());
        assert_eq!(rejected_identity, INVALID_KEY_HANDLE);
        assert_eq!(rejected_ark, INVALID_KEY_HANDLE);

        let mut tampered_pending_blob = pending_blob;
        tampered_pending_blob[device_core::DEVICE_STATE_BLOB_LENGTH - 1] ^= 1;
        rejected_binding = sentinel_device_state_binding();
        rejected_identity = u64::MAX;
        rejected_ark = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    tampered_pending_blob.as_ptr(),
                    tampered_pending_blob.len(),
                    &mut rejected_binding,
                    &mut rejected_identity,
                    &mut rejected_ark,
                )
            },
            KelivoStatus::DeviceStateAuthenticationFailed.code()
        );
        assert_eq!(rejected_binding, KelivoDeviceStateBinding::default());
        assert_eq!(rejected_identity, INVALID_KEY_HANDLE);
        assert_eq!(rejected_ark, INVALID_KEY_HANDLE);

        let mut pending_binding = KelivoDeviceStateBinding::default();
        let mut reopened_target = INVALID_KEY_HANDLE;
        let mut absent_ark = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    pending_blob.as_ptr(),
                    pending_blob.len(),
                    &mut pending_binding,
                    &mut reopened_target,
                    &mut absent_ark,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            pending_binding.struct_size,
            device_core::DEVICE_STATE_BINDING_STRUCT_SIZE
        );
        assert_eq!(pending_binding.flags, 0);
        assert_eq!(pending_binding.device_id, target_device_id);
        assert_eq!(pending_binding.key_version, key_version);
        assert_eq!(pending_binding.user_id, [0; 16]);
        assert_eq!(pending_binding.key_epoch, 0);
        assert!(handle_has_tag(reopened_target, DEVICE_IDENTITY_HANDLE_TAG));
        assert_eq!(absent_ark, INVALID_KEY_HANDLE);

        let target_public_keys = device_public_keys(reopened_target);
        let issuer_public_keys = device_public_keys(issuer_identity);
        let mut pending_handle = INVALID_KEY_HANDLE;
        let mut pairing_material = [0_u8; device_core::PENDING_PAIRING_MATERIAL_LENGTH];
        let mut pairing_material_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_pending_pairing_start(
                    reopened_target,
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    key_version,
                    &mut pending_handle,
                    pairing_material.as_mut_ptr(),
                    pairing_material.len(),
                    &mut pairing_material_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert!(handle_has_tag(pending_handle, PENDING_PAIRING_HANDLE_TAG));
        assert_eq!(pairing_material_length, pairing_material.len());
        let pairing_id = &pairing_material[..16];
        let pairing_secret = &pairing_material[16..48];
        assert_eq!(
            &pairing_material[48..],
            crypto::Sha256Digest::of(pairing_secret).as_bytes()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(pending_handle),
            KelivoStatus::InvalidAccountRootKeyHandle.code()
        );

        assert_eq!(
            unsafe {
                kelivo_pending_pairing_bind(
                    pending_handle,
                    1,
                    pairing_id.as_ptr(),
                    pairing_id.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    key_version,
                    issuer_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    issuer_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    expires_at_ms,
                    challenge.as_ptr(),
                    challenge.len(),
                    now_ms,
                )
            },
            KelivoStatus::DeviceAuthenticationFailed.code()
        );
        assert_eq!(
            unsafe {
                kelivo_pending_pairing_bind(
                    pending_handle,
                    1,
                    pairing_id.as_ptr(),
                    pairing_id.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    key_version,
                    target_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    expires_at_ms + 1,
                    challenge.as_ptr(),
                    challenge.len(),
                    now_ms,
                )
            },
            KelivoStatus::DeviceMessageInvalid.code()
        );
        assert_eq!(
            unsafe {
                kelivo_pending_pairing_bind(
                    pending_handle,
                    1,
                    pairing_id.as_ptr(),
                    pairing_id.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    key_version,
                    target_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    expires_at_ms,
                    challenge.as_ptr(),
                    challenge.len(),
                    now_ms,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            unsafe {
                kelivo_pending_pairing_bind(
                    pending_handle,
                    1,
                    pairing_id.as_ptr(),
                    pairing_id.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    key_version,
                    target_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    expires_at_ms,
                    challenge.as_ptr(),
                    challenge.len(),
                    now_ms,
                )
            },
            KelivoStatus::PendingPairingStateInvalid.code()
        );

        let mut approval_bundle = [0_u8; device_core::PAIRING_APPROVAL_BUNDLE_LENGTH];
        let mut approval_bundle_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_pairing_approval_create(
                    issuer_identity,
                    issuer_ark,
                    pairing_id.as_ptr(),
                    pairing_id.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    issuer_device_id.as_ptr(),
                    issuer_device_id.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    expires_at_ms,
                    challenge.as_ptr(),
                    challenge.len(),
                    key_epoch,
                    target_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    pairing_secret.as_ptr(),
                    pairing_secret.len(),
                    approval_bundle.as_mut_ptr(),
                    approval_bundle.len(),
                    &mut approval_bundle_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(approval_bundle_length, approval_bundle.len());
        let signature_offset = crypto::ARK_ENVELOPE_LENGTH;
        let authenticator_offset = signature_offset + crypto::DEVICE_PROOF_SIGNATURE_LENGTH;

        let mut tampered_authenticator: [u8; crypto::PAIRING_AUTHENTICATOR_LENGTH] =
            approval_bundle[authenticator_offset..]
                .try_into()
                .expect("认证器长度固定");
        tampered_authenticator[0] ^= 1;
        let mut rejected_ark = u64::MAX;
        let mut rejected_blob = [0xa5_u8; device_core::DEVICE_STATE_BLOB_LENGTH];
        let mut rejected_blob_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_pairing_approval_accept(
                    key_handle,
                    reopened_target,
                    pending_handle,
                    now_ms,
                    issuer_device_id.as_ptr(),
                    issuer_device_id.len(),
                    key_epoch,
                    issuer_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    issuer_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    approval_bundle[signature_offset..authenticator_offset].as_ptr(),
                    crypto::DEVICE_PROOF_SIGNATURE_LENGTH,
                    tampered_authenticator.as_ptr(),
                    tampered_authenticator.len(),
                    approval_bundle[..signature_offset].as_ptr(),
                    crypto::ARK_ENVELOPE_LENGTH,
                    &mut rejected_ark,
                    rejected_blob.as_mut_ptr(),
                    rejected_blob.len(),
                    &mut rejected_blob_length,
                )
            },
            KelivoStatus::DeviceAuthenticationFailed.code()
        );
        assert_eq!(rejected_ark, INVALID_KEY_HANDLE);
        assert_eq!(rejected_blob_length, 0);
        assert!(rejected_blob.iter().all(|byte| *byte == 0xa5));

        let mut installed_ark = INVALID_KEY_HANDLE;
        let mut full_blob = [0_u8; device_core::DEVICE_STATE_BLOB_LENGTH];
        let mut full_blob_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_pairing_approval_accept(
                    key_handle,
                    reopened_target,
                    pending_handle,
                    expires_at_ms - 1,
                    issuer_device_id.as_ptr(),
                    issuer_device_id.len(),
                    key_epoch,
                    issuer_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    issuer_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    approval_bundle[signature_offset..authenticator_offset].as_ptr(),
                    crypto::DEVICE_PROOF_SIGNATURE_LENGTH,
                    approval_bundle[authenticator_offset..].as_ptr(),
                    crypto::PAIRING_AUTHENTICATOR_LENGTH,
                    approval_bundle[..signature_offset].as_ptr(),
                    crypto::ARK_ENVELOPE_LENGTH,
                    &mut installed_ark,
                    full_blob.as_mut_ptr(),
                    full_blob.len(),
                    &mut full_blob_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert!(handle_has_tag(installed_ark, ACCOUNT_ROOT_KEY_HANDLE_TAG));
        assert_eq!(full_blob_length, full_blob.len());

        let mut consumed_ark = u64::MAX;
        let mut consumed_blob = [0xa5_u8; device_core::DEVICE_STATE_BLOB_LENGTH];
        let mut consumed_blob_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_pairing_approval_accept(
                    key_handle,
                    reopened_target,
                    pending_handle,
                    now_ms,
                    issuer_device_id.as_ptr(),
                    issuer_device_id.len(),
                    key_epoch,
                    issuer_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    issuer_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    approval_bundle[signature_offset..authenticator_offset].as_ptr(),
                    crypto::DEVICE_PROOF_SIGNATURE_LENGTH,
                    approval_bundle[authenticator_offset..].as_ptr(),
                    crypto::PAIRING_AUTHENTICATOR_LENGTH,
                    approval_bundle[..signature_offset].as_ptr(),
                    crypto::ARK_ENVELOPE_LENGTH,
                    &mut consumed_ark,
                    consumed_blob.as_mut_ptr(),
                    consumed_blob.len(),
                    &mut consumed_blob_length,
                )
            },
            KelivoStatus::InvalidPendingPairingHandle.code()
        );
        assert_eq!(consumed_ark, INVALID_KEY_HANDLE);
        assert_eq!(consumed_blob_length, 0);
        assert!(consumed_blob.iter().all(|byte| *byte == 0xa5));
        assert_eq!(
            kelivo_pending_pairing_handle_close(pending_handle),
            KelivoStatus::InvalidPendingPairingHandle.code()
        );

        let mut full_binding = KelivoDeviceStateBinding::default();
        let mut full_identity = INVALID_KEY_HANDLE;
        let mut full_ark = INVALID_KEY_HANDLE;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    full_blob.as_ptr(),
                    full_blob.len(),
                    &mut full_binding,
                    &mut full_identity,
                    &mut full_ark,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            full_binding.struct_size,
            device_core::DEVICE_STATE_BINDING_STRUCT_SIZE
        );
        assert_eq!(
            full_binding.flags,
            device_core::DEVICE_STATE_BINDING_FLAG_ACCOUNT
        );
        assert_eq!(full_binding.device_id, target_device_id);
        assert_eq!(full_binding.key_version, key_version);
        assert_eq!(full_binding.user_id, user_id);
        assert_eq!(full_binding.key_epoch, key_epoch);
        assert_eq!(device_public_keys(full_identity), target_public_keys);
        assert!(handle_has_tag(full_ark, ACCOUNT_ROOT_KEY_HANDLE_TAG));

        assert_eq!(
            kelivo_account_root_key_handle_close(full_ark),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(full_identity),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(installed_ark),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(reopened_target),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(issuer_ark),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(issuer_identity),
            KelivoStatus::Ok.code()
        );
        assert_eq!(close_key_handle(key_handle), Ok(()));
    }

    fn seal_rotation_envelope(
        issuer_identity: u64,
        ark: u64,
        user_id: &[u8; 16],
        issuer_device_id: &[u8; 16],
        target_device_id: &[u8; 16],
        key_epoch: u32,
        target_public_keys: &[u8; device_core::DEVICE_PUBLIC_KEYS_LENGTH],
    ) -> [u8; crypto::ARK_ENVELOPE_LENGTH] {
        let mut envelope = [0xa5_u8; crypto::ARK_ENVELOPE_LENGTH];
        let mut envelope_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_envelope_seal(
                    issuer_identity,
                    ark,
                    user_id.as_ptr(),
                    user_id.len(),
                    issuer_device_id.as_ptr(),
                    issuer_device_id.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    key_epoch,
                    target_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    envelope.as_mut_ptr(),
                    envelope.len(),
                    &mut envelope_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(envelope_length, envelope.len());
        envelope
    }

    #[test]
    fn ark_rotation_envelope_round_trips_maximum_epoch_without_exporting_ark() {
        let issuer_identity = generate_device_identity();
        let target_identity = generate_device_identity();
        let issuer_public_keys = device_public_keys(issuer_identity);
        let target_public_keys = device_public_keys(target_identity);
        let user_id = account_id(0x91);
        let issuer_ark = generate_ark(&user_id, u32::MAX);
        let issuer_device_id = account_id(0x92);
        let target_device_id = account_id(0x93);
        let envelope = seal_rotation_envelope(
            issuer_identity,
            issuer_ark,
            &user_id,
            &issuer_device_id,
            &target_device_id,
            u32::MAX,
            &target_public_keys,
        );

        let mut opened_ark = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_envelope_open(
                    target_identity,
                    envelope.as_ptr(),
                    envelope.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    issuer_device_id.as_ptr(),
                    issuer_device_id.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    u32::MAX,
                    issuer_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    issuer_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    &mut opened_ark,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert!(handle_has_tag(opened_ark, ACCOUNT_ROOT_KEY_HANDLE_TAG));

        let canonical_key = b"chat-message/ark-rotation-proof";
        let mut original_record_id = [0_u8; device_core::DERIVED_RECORD_ID_LENGTH];
        let mut original_length = 0_usize;
        let mut opened_record_id = [0_u8; device_core::DERIVED_RECORD_ID_LENGTH];
        let mut opened_length = 0_usize;
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    issuer_ark,
                    canonical_key.as_ptr(),
                    canonical_key.len(),
                    u32::MAX,
                    original_record_id.as_mut_ptr(),
                    original_record_id.len(),
                    &mut original_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            unsafe {
                kelivo_account_record_id_derive(
                    opened_ark,
                    canonical_key.as_ptr(),
                    canonical_key.len(),
                    u32::MAX,
                    opened_record_id.as_mut_ptr(),
                    opened_record_id.len(),
                    &mut opened_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(original_length, original_record_id.len());
        assert_eq!(opened_length, opened_record_id.len());
        assert_eq!(opened_record_id, original_record_id);

        assert_eq!(
            kelivo_account_root_key_handle_close(opened_ark),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(issuer_ark),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(target_identity),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(issuer_identity),
            KelivoStatus::Ok.code()
        );
    }

    #[allow(clippy::too_many_arguments)]
    fn open_rotation_envelope(
        identity: u64,
        envelope: &[u8],
        user_id: &[u8; 16],
        issuer_device_id: &[u8; 16],
        target_device_id: &[u8; 16],
        key_epoch: u32,
        issuer_public_keys: &[u8; device_core::DEVICE_PUBLIC_KEYS_LENGTH],
        target_public_keys: &[u8; device_core::DEVICE_PUBLIC_KEYS_LENGTH],
    ) -> (i32, u64) {
        let mut output = u64::MAX;
        let status = unsafe {
            kelivo_account_root_key_envelope_open(
                identity,
                envelope.as_ptr(),
                envelope.len(),
                user_id.as_ptr(),
                user_id.len(),
                issuer_device_id.as_ptr(),
                issuer_device_id.len(),
                target_device_id.as_ptr(),
                target_device_id.len(),
                key_epoch,
                issuer_public_keys.as_ptr(),
                crypto::DEVICE_PUBLIC_KEY_LENGTH,
                issuer_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                crypto::DEVICE_PUBLIC_KEY_LENGTH,
                target_public_keys.as_ptr(),
                crypto::DEVICE_PUBLIC_KEY_LENGTH,
                target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                crypto::DEVICE_PUBLIC_KEY_LENGTH,
                &mut output,
            )
        };
        (status, output)
    }

    #[test]
    fn ark_rotation_envelope_rejects_binding_tampering_and_invalid_handles() {
        let issuer_identity = generate_device_identity();
        let target_identity = generate_device_identity();
        let other_identity = generate_device_identity();
        let issuer_public_keys = device_public_keys(issuer_identity);
        let target_public_keys = device_public_keys(target_identity);
        let other_public_keys = device_public_keys(other_identity);
        let user_id = account_id(0xa1);
        let issuer_ark = generate_ark(&user_id, 7);
        let issuer_device_id = account_id(0xa2);
        let target_device_id = account_id(0xa3);
        let envelope = seal_rotation_envelope(
            issuer_identity,
            issuer_ark,
            &user_id,
            &issuer_device_id,
            &target_device_id,
            7,
            &target_public_keys,
        );

        let other_user_id = account_id(0xa4);
        let mut cross_account_output = [0xa5_u8; crypto::ARK_ENVELOPE_LENGTH];
        let mut cross_account_output_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_envelope_seal(
                    issuer_identity,
                    issuer_ark,
                    other_user_id.as_ptr(),
                    other_user_id.len(),
                    issuer_device_id.as_ptr(),
                    issuer_device_id.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    7,
                    target_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    cross_account_output.as_mut_ptr(),
                    cross_account_output.len(),
                    &mut cross_account_output_length,
                )
            },
            KelivoStatus::DeviceAuthenticationFailed.code()
        );
        assert_eq!(cross_account_output_length, 0);
        assert!(cross_account_output.iter().all(|byte| *byte == 0));

        let mut undersized_output = [0xa5_u8; crypto::ARK_ENVELOPE_LENGTH - 1];
        let mut required_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_envelope_seal(
                    issuer_identity,
                    issuer_ark,
                    user_id.as_ptr(),
                    user_id.len(),
                    issuer_device_id.as_ptr(),
                    issuer_device_id.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    7,
                    target_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    undersized_output.as_mut_ptr(),
                    undersized_output.len(),
                    &mut required_length,
                )
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        assert_eq!(required_length, crypto::ARK_ENVELOPE_LENGTH);
        assert!(undersized_output.iter().all(|byte| *byte == 0));

        for (identity, ark, epoch, expected_status) in [
            (
                issuer_identity,
                issuer_identity,
                7,
                KelivoStatus::InvalidAccountRootKeyHandle,
            ),
            (
                issuer_ark,
                issuer_ark,
                7,
                KelivoStatus::InvalidDeviceIdentityHandle,
            ),
            (
                issuer_identity,
                issuer_ark,
                0,
                KelivoStatus::DeviceMessageInvalid,
            ),
        ] {
            let mut rejected_envelope = [0xa5_u8; crypto::ARK_ENVELOPE_LENGTH];
            let mut rejected_length = usize::MAX;
            assert_eq!(
                unsafe {
                    kelivo_account_root_key_envelope_seal(
                        identity,
                        ark,
                        user_id.as_ptr(),
                        user_id.len(),
                        issuer_device_id.as_ptr(),
                        issuer_device_id.len(),
                        target_device_id.as_ptr(),
                        target_device_id.len(),
                        epoch,
                        target_public_keys.as_ptr(),
                        crypto::DEVICE_PUBLIC_KEY_LENGTH,
                        target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                        crypto::DEVICE_PUBLIC_KEY_LENGTH,
                        rejected_envelope.as_mut_ptr(),
                        rejected_envelope.len(),
                        &mut rejected_length,
                    )
                },
                expected_status.code()
            );
            assert_eq!(rejected_length, 0);
            assert!(rejected_envelope.iter().all(|byte| *byte == 0));
        }

        let changed_bindings = [
            (account_id(0xb1), issuer_device_id, target_device_id, 7),
            (user_id, account_id(0xb2), target_device_id, 7),
            (user_id, issuer_device_id, account_id(0xb3), 7),
            (user_id, issuer_device_id, target_device_id, 8),
        ];
        for (candidate_user, candidate_issuer, candidate_target, candidate_epoch) in
            changed_bindings
        {
            let (status, output) = open_rotation_envelope(
                target_identity,
                &envelope,
                &candidate_user,
                &candidate_issuer,
                &candidate_target,
                candidate_epoch,
                &issuer_public_keys,
                &target_public_keys,
            );
            assert_eq!(status, KelivoStatus::DeviceAuthenticationFailed.code());
            assert_eq!(output, INVALID_KEY_HANDLE);
        }

        let mut wrong_issuer_signing = issuer_public_keys;
        wrong_issuer_signing[..crypto::DEVICE_PUBLIC_KEY_LENGTH]
            .copy_from_slice(&other_public_keys[..crypto::DEVICE_PUBLIC_KEY_LENGTH]);
        let mut wrong_issuer_agreement = issuer_public_keys;
        wrong_issuer_agreement[crypto::DEVICE_PUBLIC_KEY_LENGTH..]
            .copy_from_slice(&other_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..]);
        let mut wrong_target_signing = target_public_keys;
        wrong_target_signing[..crypto::DEVICE_PUBLIC_KEY_LENGTH]
            .copy_from_slice(&other_public_keys[..crypto::DEVICE_PUBLIC_KEY_LENGTH]);
        let mut wrong_target_agreement = target_public_keys;
        wrong_target_agreement[crypto::DEVICE_PUBLIC_KEY_LENGTH..]
            .copy_from_slice(&other_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..]);
        for (candidate_issuer_keys, candidate_target_keys) in [
            (&wrong_issuer_signing, &target_public_keys),
            (&wrong_issuer_agreement, &target_public_keys),
            (&issuer_public_keys, &wrong_target_signing),
            (&issuer_public_keys, &wrong_target_agreement),
        ] {
            let (status, output) = open_rotation_envelope(
                target_identity,
                &envelope,
                &user_id,
                &issuer_device_id,
                &target_device_id,
                7,
                candidate_issuer_keys,
                candidate_target_keys,
            );
            assert_eq!(status, KelivoStatus::DeviceAuthenticationFailed.code());
            assert_eq!(output, INVALID_KEY_HANDLE);
        }

        let mut tampered_envelope = envelope;
        tampered_envelope[crypto::ARK_ENVELOPE_LENGTH - 1] ^= 1;
        for (identity, candidate_envelope, expected_status) in [
            (
                target_identity,
                tampered_envelope.as_slice(),
                KelivoStatus::DeviceAuthenticationFailed,
            ),
            (
                target_identity,
                &envelope[..crypto::ARK_ENVELOPE_LENGTH - 1],
                KelivoStatus::DeviceMessageInvalid,
            ),
            (
                issuer_ark,
                envelope.as_slice(),
                KelivoStatus::InvalidDeviceIdentityHandle,
            ),
            (
                other_identity,
                envelope.as_slice(),
                KelivoStatus::DeviceAuthenticationFailed,
            ),
        ] {
            let (status, output) = open_rotation_envelope(
                identity,
                candidate_envelope,
                &user_id,
                &issuer_device_id,
                &target_device_id,
                7,
                &issuer_public_keys,
                &target_public_keys,
            );
            assert_eq!(status, expected_status.code());
            assert_eq!(output, INVALID_KEY_HANDLE);
        }

        let invalid_uuid = [0_u8; 16];
        for (candidate_user, epoch) in [(invalid_uuid, 7), (user_id, 0)] {
            let (status, output) = open_rotation_envelope(
                target_identity,
                &envelope,
                &candidate_user,
                &issuer_device_id,
                &target_device_id,
                epoch,
                &issuer_public_keys,
                &target_public_keys,
            );
            assert_eq!(status, KelivoStatus::DeviceMessageInvalid.code());
            assert_eq!(output, INVALID_KEY_HANDLE);
        }

        let mut invalid_key_output = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_envelope_open(
                    target_identity,
                    envelope.as_ptr(),
                    envelope.len(),
                    user_id.as_ptr(),
                    user_id.len(),
                    issuer_device_id.as_ptr(),
                    issuer_device_id.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    7,
                    issuer_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH - 1,
                    issuer_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys.as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    target_public_keys[crypto::DEVICE_PUBLIC_KEY_LENGTH..].as_ptr(),
                    crypto::DEVICE_PUBLIC_KEY_LENGTH,
                    &mut invalid_key_output,
                )
            },
            KelivoStatus::DeviceMessageInvalid.code()
        );
        assert_eq!(invalid_key_output, INVALID_KEY_HANDLE);

        assert_eq!(
            kelivo_device_identity_handle_close(target_identity),
            KelivoStatus::Ok.code()
        );
        let (status, output) = open_rotation_envelope(
            target_identity,
            &envelope,
            &user_id,
            &issuer_device_id,
            &target_device_id,
            7,
            &issuer_public_keys,
            &target_public_keys,
        );
        assert_eq!(status, KelivoStatus::InvalidDeviceIdentityHandle.code());
        assert_eq!(output, INVALID_KEY_HANDLE);

        assert_eq!(
            kelivo_account_root_key_handle_close(issuer_ark),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(other_identity),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_device_identity_handle_close(issuer_identity),
            KelivoStatus::Ok.code()
        );
    }

    #[test]
    fn recovery_media_one_shot_publishes_ark_only_after_history_verification() {
        let _guard = recovery_test_guard();
        assert_eq!(recovery::active_recovery_handles(), 0);
        let user_id = account_id(0x71);
        let protocol_user_id = crypto::UserId::new(user_id).expect("测试账户应有效");
        let ark_bytes = [0x72; 32];
        let source_ark_handle = device_core::register_ark(
            protocol_user_id,
            1,
            crypto::AccountRootKey::from_bytes(ark_bytes),
        )
        .expect("测试 ARK 应注册");
        let (recovery_handle, recovery_public_key) = generate_test_recovery_identity(&user_id);
        let capsule =
            seal_test_recovery_capsule(source_ark_handle, &user_id, 1, 1, &recovery_public_key);
        let genesis =
            build_test_recovery_genesis(ark_bytes, user_id, recovery_public_key, &capsule);
        let export_authority = recovery_media_export_authority(source_ark_handle, capsule);
        let passphrase = "甲乙丙丁戊己庚辛壬癸子丑".as_bytes();
        let origin = [0x73; recovery_protocol::RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH];
        let mut media = [0xa5; recovery_protocol::RECOVERY_MEDIA_LENGTH];
        let mut media_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_recovery_media_export(
                    recovery_handle,
                    &export_authority,
                    genesis.as_ptr(),
                    genesis.len(),
                    passphrase.as_ptr(),
                    passphrase.len(),
                    origin.as_ptr(),
                    origin.len(),
                    media.as_mut_ptr(),
                    media.len(),
                    &mut media_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(media_length, media.len());
        assert_eq!(
            kelivo_recovery_handle_close(recovery_handle),
            KelivoStatus::Ok.code()
        );

        let wrong_password = b"incorrect-password";
        let mut failed_binding = sentinel_recovery_capsule_binding();
        let mut failed_ark_handle = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_recovery_media_import_history_verify_and_capsule_open(
                    media.as_ptr(),
                    media.len(),
                    wrong_password.as_ptr(),
                    wrong_password.len(),
                    origin.as_ptr(),
                    origin.len(),
                    genesis.as_ptr(),
                    genesis.len(),
                    ptr::null(),
                    0,
                    capsule.as_ptr(),
                    capsule.len(),
                    &mut failed_binding,
                    &mut failed_ark_handle,
                )
            },
            KelivoStatus::RecoveryMediaAuthenticationFailed.code()
        );
        assert_eq!(failed_binding, KelivoRecoveryCapsuleBinding::default());
        assert_eq!(failed_ark_handle, INVALID_KEY_HANDLE);

        let mut wrong_history = genesis;
        wrong_history[20] ^= 1;
        failed_binding = sentinel_recovery_capsule_binding();
        failed_ark_handle = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_recovery_media_import_history_verify_and_capsule_open(
                    media.as_ptr(),
                    media.len(),
                    passphrase.as_ptr(),
                    passphrase.len(),
                    origin.as_ptr(),
                    origin.len(),
                    wrong_history.as_ptr(),
                    wrong_history.len(),
                    ptr::null(),
                    0,
                    capsule.as_ptr(),
                    capsule.len(),
                    &mut failed_binding,
                    &mut failed_ark_handle,
                )
            },
            KelivoStatus::RecoveryHistoryInvalid.code()
        );
        assert_eq!(failed_binding, KelivoRecoveryCapsuleBinding::default());
        assert_eq!(failed_ark_handle, INVALID_KEY_HANDLE);

        let oversized_history = vec![0_u8; recovery_protocol::RECOVERY_HISTORY_MAX_BYTES + 1];
        failed_binding = sentinel_recovery_capsule_binding();
        failed_ark_handle = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_recovery_media_import_history_verify_and_capsule_open(
                    media.as_ptr(),
                    media.len(),
                    passphrase.as_ptr(),
                    passphrase.len(),
                    origin.as_ptr(),
                    origin.len(),
                    oversized_history.as_ptr(),
                    oversized_history.len(),
                    ptr::null(),
                    0,
                    capsule.as_ptr(),
                    capsule.len(),
                    &mut failed_binding,
                    &mut failed_ark_handle,
                )
            },
            KelivoStatus::RecoveryHistoryInvalid.code()
        );
        assert_eq!(failed_binding, KelivoRecoveryCapsuleBinding::default());
        assert_eq!(failed_ark_handle, INVALID_KEY_HANDLE);

        let mut opened_binding = sentinel_recovery_capsule_binding();
        let mut opened_ark_handle = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_recovery_media_import_history_verify_and_capsule_open(
                    media.as_ptr(),
                    media.len(),
                    passphrase.as_ptr(),
                    passphrase.len(),
                    origin.as_ptr(),
                    origin.len(),
                    genesis.as_ptr(),
                    genesis.len(),
                    ptr::null(),
                    0,
                    capsule.as_ptr(),
                    capsule.len(),
                    &mut opened_binding,
                    &mut opened_ark_handle,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            opened_binding,
            KelivoRecoveryCapsuleBinding {
                struct_size: recovery::RECOVERY_CAPSULE_BINDING_STRUCT_SIZE,
                user_id,
                key_epoch: 1,
                capsule_version: 1,
            }
        );
        let opened_ark =
            device_core::ark_for_account_handle(opened_ark_handle, protocol_user_id, 1)
                .expect("恢复 ARK 应可用");
        assert_eq!(opened_ark.as_bytes(), &ark_bytes);
        assert_eq!(recovery::active_recovery_handles(), 0);
        assert_eq!(
            kelivo_account_root_key_handle_close(opened_ark_handle),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(source_ark_handle),
            KelivoStatus::Ok.code()
        );
    }

    #[test]
    fn recovered_keyring_registers_only_adjacent_epochs() {
        let user_id = crypto::UserId::new(account_id(0x79)).expect("测试账户应有效");
        let handle = device_core::register_recovered_ark_keyring(
            user_id,
            Some((1, crypto::AccountRootKey::from_bytes([0x7a; 32]))),
            2,
            crypto::AccountRootKey::from_bytes([0x7b; 32]),
        )
        .expect("相邻两代恢复 ARK 应原子注册");
        assert_eq!(
            device_core::ark_for_account_handle(handle, user_id, 1)
                .expect("源代次应存在")
                .as_bytes(),
            &[0x7a; 32]
        );
        assert_eq!(
            device_core::ark_for_account_handle(handle, user_id, 2)
                .expect("当前代次应存在")
                .as_bytes(),
            &[0x7b; 32]
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(handle),
            KelivoStatus::Ok.code()
        );

        assert_eq!(
            device_core::register_recovered_ark_keyring(
                user_id,
                Some((1, crypto::AccountRootKey::from_bytes([0x7c; 32]))),
                3,
                crypto::AccountRootKey::from_bytes([0x7d; 32]),
            )
            .expect_err("非相邻恢复代次必须失败"),
            KelivoStatus::RecoveryHistoryInvalid
        );
    }

    #[test]
    fn recovery_handles_enforce_capacity_concurrent_close_and_failure_zeroing() {
        let _guard = recovery_test_guard();
        assert_eq!(recovery::active_recovery_handles(), 0);
        let user_id = account_id(0x81);
        let mut handles = Vec::new();
        for _ in 0..64 {
            let (handle, _) = generate_test_recovery_identity(&user_id);
            handles.push(handle);
        }
        assert_eq!(recovery::active_recovery_handles(), 64);

        let mut overflow_handle = u64::MAX;
        let mut overflow_public_key = [0xa5; recovery_protocol::RECOVERY_PUBLIC_KEY_LENGTH];
        let mut overflow_public_key_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_recovery_identity_generate(
                    user_id.as_ptr(),
                    user_id.len(),
                    1,
                    &mut overflow_handle,
                    overflow_public_key.as_mut_ptr(),
                    overflow_public_key.len(),
                    &mut overflow_public_key_length,
                )
            },
            KelivoStatus::TooManyActiveHandles.code()
        );
        assert_eq!(overflow_handle, INVALID_KEY_HANDLE);
        assert_eq!(overflow_public_key_length, 0);
        assert!(overflow_public_key.iter().all(|byte| *byte == 0));

        let borrowed = recovery::borrow_test_recovery(handles[0]).expect("测试借用应成功");
        assert_eq!(
            kelivo_recovery_handle_close(handles[0]),
            KelivoStatus::SlotInUse.code()
        );
        drop(borrowed);
        assert_eq!(
            kelivo_recovery_handle_close(handles.remove(0)),
            KelivoStatus::Ok.code()
        );
        for handle in handles {
            assert_eq!(
                kelivo_recovery_handle_close(handle),
                KelivoStatus::Ok.code()
            );
        }
        assert_eq!(recovery::active_recovery_handles(), 0);

        let mut invalid_handle = u64::MAX;
        let mut invalid_public_key = [0xa5; recovery_protocol::RECOVERY_PUBLIC_KEY_LENGTH];
        let mut invalid_public_key_length = usize::MAX;
        let invalid_user_id = [0_u8; 16];
        assert_eq!(
            unsafe {
                kelivo_recovery_identity_generate(
                    invalid_user_id.as_ptr(),
                    invalid_user_id.len(),
                    1,
                    &mut invalid_handle,
                    invalid_public_key.as_mut_ptr(),
                    invalid_public_key.len(),
                    &mut invalid_public_key_length,
                )
            },
            KelivoStatus::InvalidAccountId.code()
        );
        assert_eq!(invalid_handle, INVALID_KEY_HANDLE);
        assert_eq!(invalid_public_key_length, 0);
        assert!(invalid_public_key.iter().all(|byte| *byte == 0));

        let mut short_media_ark_handle = u64::MAX;
        let mut short_media_binding = sentinel_recovery_capsule_binding();
        let passphrase = b"recovery-password-v1";
        let origin = [0x82; recovery_protocol::RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH];
        let short_media = [0_u8; recovery_protocol::RECOVERY_MEDIA_LENGTH - 1];
        assert_eq!(
            unsafe {
                kelivo_recovery_media_import_history_verify_and_capsule_open(
                    short_media.as_ptr(),
                    short_media.len(),
                    passphrase.as_ptr(),
                    passphrase.len(),
                    origin.as_ptr(),
                    origin.len(),
                    ptr::null(),
                    0,
                    ptr::null(),
                    0,
                    ptr::null(),
                    0,
                    &mut short_media_binding,
                    &mut short_media_ark_handle,
                )
            },
            KelivoStatus::RecoveryMediaInvalid.code()
        );
        assert_eq!(short_media_ark_handle, INVALID_KEY_HANDLE);
        assert_eq!(short_media_binding, KelivoRecoveryCapsuleBinding::default());
    }
}
