#![forbid(unsafe_op_in_unsafe_fn)]

use core::{ffi::c_void, mem::size_of, slice};
use std::{
    collections::HashMap,
    sync::{Arc, Mutex, OnceLock},
};
use zeroize::Zeroizing;

mod database;
mod device_core;
mod opaque_client;
mod record;

pub use device_core::{
    kelivo_account_root_key_generate, kelivo_account_root_key_handle_close,
    kelivo_device_identity_generate, kelivo_device_identity_handle_close,
    kelivo_device_identity_public_keys, kelivo_device_login_proof_sign,
    kelivo_device_pairing_approval_accept, kelivo_device_pairing_approval_create,
    kelivo_device_registration_finish_create, kelivo_device_state_open, kelivo_device_state_seal,
    kelivo_pending_pairing_bind, kelivo_pending_pairing_handle_close, kelivo_pending_pairing_start,
};
pub use opaque_client::{
    kelivo_opaque_client_login_finish, kelivo_opaque_client_login_start,
    kelivo_opaque_client_registration_finish, kelivo_opaque_client_registration_start,
    kelivo_opaque_client_state_close,
};

#[cfg(target_os = "windows")]
mod windows;
#[cfg(target_os = "windows")]
use windows as platform;
#[cfg(target_os = "android")]
mod android;
#[cfg(target_os = "android")]
use android as platform;

const ABI_VERSION: u32 = 4;
const CAPABILITIES_STRUCT_SIZE: u32 = 32;
const KEY_SLOT_ID_SIZE: usize = 16;
const KEY_POLICY_VERSION: u32 = 1;
const INVALID_KEY_HANDLE: u64 = 0;
const INVALID_OPAQUE_STATE_HANDLE: u64 = 0;
// Dart FFI 只稳定往返正 63 位整数；三位类型域让五类秘密句柄互不兼容。
const HANDLE_TAG_MASK: u64 = 0b111 << 60;
const HANDLE_SEQUENCE_MASK: u64 = (1_u64 << 60) - 1;
const HANDLE_RESERVED_MASK: u64 = 1_u64 << 63;
const KEY_HANDLE_TAG: u64 = 0b001 << 60;
const OPAQUE_STATE_HANDLE_TAG: u64 = 0b010 << 60;
const DEVICE_IDENTITY_HANDLE_TAG: u64 = 0b011 << 60;
const ACCOUNT_ROOT_KEY_HANDLE_TAG: u64 = 0b100 << 60;
const PENDING_PAIRING_HANDLE_TAG: u64 = 0b101 << 60;
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
#[cfg(any(target_os = "android", target_os = "windows"))]
const KEY_SLOTS_CAPABILITY: u64 = 1 << 0;
#[cfg(any(target_os = "android", target_os = "windows"))]
const BACKGROUND_ACCESS_CAPABILITY: u64 = 1 << 1;
#[cfg(any(target_os = "android", target_os = "windows"))]
const RECORD_ENVELOPES_CAPABILITY: u64 = 1 << 2;
#[cfg(any(target_os = "android", target_os = "windows"))]
const SQLCIPHER_KEY_APPLICATION_CAPABILITY: u64 = 1 << 3;
#[cfg(any(target_os = "android", target_os = "windows"))]
const SQLCIPHER_DATABASE_ATTACH_CAPABILITY: u64 = 1 << 4;
const OPAQUE_CLIENT_CAPABILITY: u64 = 1 << 5;
const DEVICE_E2EE_CORE_CAPABILITY: u64 = 1 << 6;
#[cfg(any(target_os = "android", target_os = "windows"))]
pub(crate) const LOCAL_KEY_SIZE: usize = 32;

type LocalKey = Zeroizing<Box<[u8]>>;

#[cfg(not(any(target_os = "android", target_os = "windows")))]
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

unsafe fn validate_key_slot_request(
    slot_id: *const u8,
    slot_id_length: usize,
    policy_version: u32,
    out_handle: *mut u64,
) -> Result<[u8; KEY_SLOT_ID_SIZE], KelivoStatus> {
    unsafe {
        write_output(out_handle, INVALID_KEY_HANDLE)?;
    }

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

struct KeyRegistry {
    active: HashMap<u64, Arc<LocalKey>>,
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

fn register_key(key: LocalKey) -> Result<u64, KelivoStatus> {
    let mut registry = key_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;

    if registry.active.len() >= MAX_ACTIVE_KEY_HANDLES {
        return Err(KelivoStatus::TooManyActiveHandles);
    }
    let handle = issue_typed_handle(KEY_HANDLE_TAG, &mut registry.next_sequence)?;
    let replaced = registry.active.insert(handle, Arc::new(key));
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
        .cloned()
        .ok_or(KelivoStatus::InvalidKeyHandle)
}

fn close_key_handle(handle: u64) -> Result<(), KelivoStatus> {
    if !handle_has_tag(handle, KEY_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidKeyHandle);
    }

    let removed = key_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .remove(&handle)
        .ok_or(KelivoStatus::InvalidKeyHandle)?;
    drop(removed);
    Ok(())
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
            | if cfg!(any(target_os = "android", target_os = "windows")) {
                DEVICE_E2EE_CORE_CAPABILITY
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
    let slot_id = match unsafe {
        validate_key_slot_request(slot_id, slot_id_length, policy_version, out_handle)
    } {
        Ok(slot_id) => slot_id,
        Err(status) => return status.code(),
    };

    let key = if create {
        platform::create_slot(&slot_id)
    } else {
        platform::open_slot(&slot_id)
    };
    let handle = match key.and_then(register_key) {
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
    let key = match key_for_handle(handle) {
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
    let key = match master_key(&key) {
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
/// 所有输入指针必须覆盖声明的可读长度；输出指针必须覆盖声明的可写容量。
/// `out_plaintext_length` 必须始终可写；认证失败不得写出任何明文字节。
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
    let key = match key_for_handle(handle) {
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

    let key = match master_key(&key) {
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

#[cfg(test)]
mod tests {
    use super::*;
    use core::{ffi::c_char, ptr, slice};
    use kelivo_secure_core_protocol::device_crypto as crypto;

    fn empty_capabilities() -> KelivoCoreCapabilities {
        KelivoCoreCapabilities {
            struct_size: 0,
            abi_version: 0,
            flags: u64::MAX,
            secure_storage_backend: u32::MAX,
            reserved: [u32::MAX; 3],
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
                | if cfg!(any(target_os = "android", target_os = "windows")) {
                    DEVICE_E2EE_CORE_CAPABILITY
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

    #[cfg(not(target_os = "windows"))]
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

    fn generate_ark() -> u64 {
        let mut handle = INVALID_KEY_HANDLE;
        assert_eq!(
            unsafe { kelivo_account_root_key_generate(&mut handle) },
            KelivoStatus::Ok.code()
        );
        assert!(handle_has_tag(handle, ACCOUNT_ROOT_KEY_HANDLE_TAG));
        handle
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
    fn device_and_ark_handles_are_strongly_typed_and_close_once() {
        let identity = generate_device_identity();
        let ark = generate_ark();
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
    fn registration_and_login_proofs_hash_only_strict_raw_payloads_in_rust() {
        let identity = generate_device_identity();
        let ark = generate_ark();
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
        let user_id = account_id(0x41);
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
        let issuer_ark = generate_ark();
        let target_identity = generate_device_identity();
        let target_device_id = account_id(0x31);
        let issuer_device_id = account_id(0x32);
        let user_id = account_id(0x33);
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

        let mut reopened_target = INVALID_KEY_HANDLE;
        let mut absent_ark = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    pending_blob.as_ptr(),
                    pending_blob.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    key_version,
                    ptr::null(),
                    0,
                    0,
                    &mut reopened_target,
                    &mut absent_ark,
                )
            },
            KelivoStatus::Ok.code()
        );
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

        let mut full_identity = INVALID_KEY_HANDLE;
        let mut full_ark = INVALID_KEY_HANDLE;
        assert_eq!(
            unsafe {
                kelivo_device_state_open(
                    key_handle,
                    full_blob.as_ptr(),
                    full_blob.len(),
                    target_device_id.as_ptr(),
                    target_device_id.len(),
                    key_version,
                    user_id.as_ptr(),
                    user_id.len(),
                    key_epoch,
                    &mut full_identity,
                    &mut full_ark,
                )
            },
            KelivoStatus::Ok.code()
        );
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
}
