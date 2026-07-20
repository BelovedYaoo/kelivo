#![forbid(unsafe_op_in_unsafe_fn)]

use core::{mem::size_of, slice};
use std::{
    collections::{HashMap, HashSet},
    sync::{Mutex, OnceLock},
};
use zeroize::Zeroizing;

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
    active: HashMap<u64, LocalKey>,
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
        let replaced = registry.active.insert(candidate, key);
        debug_assert!(replaced.is_none());
        return Ok(candidate);
    }

    Err(KelivoStatus::InternalState)
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
            KEY_SLOTS_CAPABILITY | BACKGROUND_ACCESS_CAPABILITY
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
}
