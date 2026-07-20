#![forbid(unsafe_op_in_unsafe_fn)]

use core::mem::size_of;

const ABI_VERSION: u32 = 1;
const CAPABILITIES_STRUCT_SIZE: u32 = 32;
const KEY_SLOT_ID_SIZE: usize = 16;
const KEY_POLICY_VERSION: u32 = 1;
const INVALID_KEY_HANDLE: u64 = 0;

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
#[derive(Clone, Copy)]
enum KelivoStatus {
    Ok = 0,
    NullPointer = 1,
    InvalidSlotIdLength = 2,
    UnsupportedPolicy = 3,
    InvalidKeyHandle = 4,
    OutputBufferTooSmall = 5,
    UnsupportedPlatform = 100,
}

impl KelivoStatus {
    const fn code(self) -> i32 {
        self as i32
    }
}

fn write_output<T>(output: *mut T, value: T) -> Result<(), KelivoStatus> {
    if output.is_null() {
        return Err(KelivoStatus::NullPointer);
    }

    // 调用方持有输出缓冲区；这里只在完成空指针检查后执行一次定点写入。
    unsafe {
        output.write(value);
    }
    Ok(())
}

fn validate_key_slot_request(
    slot_id: *const u8,
    slot_id_length: usize,
    policy_version: u32,
    out_handle: *mut u64,
) -> Result<(), KelivoStatus> {
    write_output(out_handle, INVALID_KEY_HANDLE)?;

    if slot_id.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    if slot_id_length != KEY_SLOT_ID_SIZE {
        return Err(KelivoStatus::InvalidSlotIdLength);
    }
    if policy_version != KEY_POLICY_VERSION {
        return Err(KelivoStatus::UnsupportedPolicy);
    }

    Ok(())
}

fn unsupported_key_slot_operation(
    slot_id: *const u8,
    slot_id_length: usize,
    policy_version: u32,
    out_handle: *mut u64,
) -> i32 {
    match validate_key_slot_request(slot_id, slot_id_length, policy_version, out_handle) {
        Ok(()) => KelivoStatus::UnsupportedPlatform.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_core_abi_version() -> u32 {
    ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_core_get_capabilities(
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
        flags: 0,
        secure_storage_backend: 0,
        reserved: [0; 3],
    };

    match write_output(out_capabilities, capabilities) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_key_slot_create(
    slot_id: *const u8,
    slot_id_length: usize,
    policy_version: u32,
    out_handle: *mut u64,
) -> i32 {
    unsupported_key_slot_operation(slot_id, slot_id_length, policy_version, out_handle)
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_key_slot_open(
    slot_id: *const u8,
    slot_id_length: usize,
    policy_version: u32,
    out_handle: *mut u64,
) -> i32 {
    unsupported_key_slot_operation(slot_id, slot_id_length, policy_version, out_handle)
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_key_handle_close(handle: u64) -> i32 {
    if handle == INVALID_KEY_HANDLE {
        return KelivoStatus::InvalidKeyHandle.code();
    }

    KelivoStatus::UnsupportedPlatform.code()
}

#[cfg(test)]
mod tests {
    use super::*;
    use core::ptr;

    #[test]
    fn capabilities_reject_invalid_buffers_without_writing() {
        assert_eq!(
            kelivo_core_get_capabilities(ptr::null_mut(), size_of::<KelivoCoreCapabilities>()),
            KelivoStatus::NullPointer.code()
        );

        let original = KelivoCoreCapabilities {
            struct_size: u32::MAX,
            abi_version: u32::MAX,
            flags: u64::MAX,
            secure_storage_backend: u32::MAX,
            reserved: [u32::MAX; 3],
        };
        let mut output = original;
        assert_eq!(
            kelivo_core_get_capabilities(&mut output, size_of::<KelivoCoreCapabilities>() - 1,),
            KelivoStatus::OutputBufferTooSmall.code()
        );
        assert_eq!(output, original);
    }

    #[test]
    fn capabilities_write_the_fixed_v1_layout() {
        let mut output = KelivoCoreCapabilities {
            struct_size: 0,
            abi_version: 0,
            flags: u64::MAX,
            secure_storage_backend: u32::MAX,
            reserved: [u32::MAX; 3],
        };
        assert_eq!(
            kelivo_core_get_capabilities(&mut output, size_of::<KelivoCoreCapabilities>()),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            output.struct_size as usize,
            size_of::<KelivoCoreCapabilities>()
        );
        assert_eq!(output.abi_version, ABI_VERSION);
        assert_eq!(output.flags, 0);
        assert_eq!(output.secure_storage_backend, 0);
        assert_eq!(output.reserved, [0; 3]);
    }

    #[test]
    fn key_slot_create_rejects_every_invalid_boundary() {
        let slot_id = [0_u8; KEY_SLOT_ID_SIZE];
        let mut handle = 42_u64;

        assert_eq!(
            kelivo_key_slot_create(
                slot_id.as_ptr(),
                slot_id.len(),
                KEY_POLICY_VERSION,
                ptr::null_mut(),
            ),
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(
            kelivo_key_slot_create(ptr::null(), slot_id.len(), KEY_POLICY_VERSION, &mut handle,),
            KelivoStatus::NullPointer.code()
        );
        assert_eq!(handle, INVALID_KEY_HANDLE);

        handle = 42;
        assert_eq!(
            kelivo_key_slot_create(
                slot_id.as_ptr(),
                slot_id.len() - 1,
                KEY_POLICY_VERSION,
                &mut handle,
            ),
            KelivoStatus::InvalidSlotIdLength.code()
        );
        assert_eq!(handle, INVALID_KEY_HANDLE);

        handle = 42;
        assert_eq!(
            kelivo_key_slot_create(
                slot_id.as_ptr(),
                slot_id.len(),
                KEY_POLICY_VERSION + 1,
                &mut handle,
            ),
            KelivoStatus::UnsupportedPolicy.code()
        );
        assert_eq!(handle, INVALID_KEY_HANDLE);

        handle = 42;
        assert_eq!(
            kelivo_key_slot_create(
                slot_id.as_ptr(),
                slot_id.len(),
                KEY_POLICY_VERSION,
                &mut handle,
            ),
            KelivoStatus::UnsupportedPlatform.code()
        );
        assert_eq!(handle, INVALID_KEY_HANDLE);
    }

    #[test]
    fn key_slot_open_and_close_fail_closed() {
        let slot_id = [0_u8; KEY_SLOT_ID_SIZE];
        let mut handle = 42_u64;
        assert_eq!(
            kelivo_key_slot_open(
                slot_id.as_ptr(),
                slot_id.len(),
                KEY_POLICY_VERSION,
                &mut handle,
            ),
            KelivoStatus::UnsupportedPlatform.code()
        );
        assert_eq!(handle, INVALID_KEY_HANDLE);
        assert_eq!(
            kelivo_key_handle_close(INVALID_KEY_HANDLE),
            KelivoStatus::InvalidKeyHandle.code()
        );
        assert_eq!(
            kelivo_key_handle_close(1),
            KelivoStatus::UnsupportedPlatform.code()
        );
    }
}
