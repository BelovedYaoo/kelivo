#![forbid(unsafe_op_in_unsafe_fn)]

use core::{ffi::c_void, mem::size_of, slice};
use std::{
    collections::{HashMap, HashSet},
    sync::{Arc, Mutex, OnceLock},
};
use zeroize::Zeroizing;

mod database;
mod record;

#[cfg(target_os = "windows")]
mod windows;
#[cfg(target_os = "windows")]
use windows as platform;
#[cfg(target_os = "android")]
mod android;
#[cfg(target_os = "android")]
use android as platform;

const ABI_VERSION: u32 = 1;
const CAPABILITIES_STRUCT_SIZE: u32 = 32;
const KEY_SLOT_ID_SIZE: usize = 16;
const KEY_POLICY_VERSION: u32 = 1;
const INVALID_KEY_HANDLE: u64 = 0;
#[cfg(any(target_os = "android", target_os = "windows"))]
const KEY_SLOTS_CAPABILITY: u64 = 1 << 0;
#[cfg(any(target_os = "android", target_os = "windows"))]
const BACKGROUND_ACCESS_CAPABILITY: u64 = 1 << 1;
#[cfg(any(target_os = "android", target_os = "windows"))]
const RECORD_ENVELOPES_CAPABILITY: u64 = 1 << 2;
#[cfg(any(target_os = "android", target_os = "windows"))]
const SQLCIPHER_KEY_APPLICATION_CAPABILITY: u64 = 1 << 3;
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

#[derive(Default)]
struct KeyRegistry {
    active: HashMap<u64, Arc<LocalKey>>,
    issued: HashSet<u64>,
}

fn key_registry() -> &'static Mutex<KeyRegistry> {
    static REGISTRY: OnceLock<Mutex<KeyRegistry>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(KeyRegistry::default()))
}

fn register_key(key: LocalKey) -> Result<u64, KelivoStatus> {
    let mut registry = key_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;

    for _ in 0..64 {
        let mut candidate_bytes = [0_u8; size_of::<u64>()];
        platform::fill_random(&mut candidate_bytes)?;
        let candidate = u64::from_le_bytes(candidate_bytes);
        if candidate == INVALID_KEY_HANDLE || registry.issued.contains(&candidate) {
            continue;
        }

        registry.issued.insert(candidate);
        let replaced = registry.active.insert(candidate, Arc::new(key));
        debug_assert!(replaced.is_none());
        return Ok(candidate);
    }

    Err(KelivoStatus::InternalState)
}

fn key_for_handle(handle: u64) -> Result<Arc<LocalKey>, KelivoStatus> {
    if handle == INVALID_KEY_HANDLE {
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
    if handle == INVALID_KEY_HANDLE {
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
        flags: platform::CAPABILITY_FLAGS,
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
    use core::ptr;

    fn empty_capabilities() -> KelivoCoreCapabilities {
        KelivoCoreCapabilities {
            struct_size: 0,
            abi_version: 0,
            flags: u64::MAX,
            secure_storage_backend: u32::MAX,
            reserved: [u32::MAX; 3],
        }
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
        assert_eq!(output.flags, platform::CAPABILITY_FLAGS);
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
}
