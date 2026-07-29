use std::{
    collections::HashMap,
    sync::{Arc, Mutex, OnceLock},
};

use kelivo_secure_core_protocol::{
    self as protocol,
    attachment_crypto::{self as crypto, AttachmentCryptoError},
    device_crypto,
};

use crate::{
    ATTACHMENT_DATA_KEY_HANDLE_TAG, INVALID_KEY_HANDLE, KelivoStatus, device_core, handle_has_tag,
    issue_typed_handle, read_input, write_bytes, write_output,
};

const MAX_ACTIVE_ATTACHMENT_DATA_KEYS: usize = 64;

struct AttachmentKeyRegistry {
    active: HashMap<u64, Arc<crypto::AttachmentDataKey>>,
    next_sequence: u64,
}

impl Default for AttachmentKeyRegistry {
    fn default() -> Self {
        Self {
            active: HashMap::new(),
            next_sequence: 1,
        }
    }
}

fn attachment_key_registry() -> &'static Mutex<AttachmentKeyRegistry> {
    static REGISTRY: OnceLock<Mutex<AttachmentKeyRegistry>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(AttachmentKeyRegistry::default()))
}

fn register_attachment_key(key: crypto::AttachmentDataKey) -> Result<u64, KelivoStatus> {
    let mut registry = attachment_key_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    if registry.active.len() >= MAX_ACTIVE_ATTACHMENT_DATA_KEYS {
        return Err(KelivoStatus::TooManyActiveHandles);
    }
    let handle = issue_typed_handle(ATTACHMENT_DATA_KEY_HANDLE_TAG, &mut registry.next_sequence)?;
    let replaced = registry.active.insert(handle, Arc::new(key));
    debug_assert!(replaced.is_none());
    Ok(handle)
}

fn attachment_key_for_handle(handle: u64) -> Result<Arc<crypto::AttachmentDataKey>, KelivoStatus> {
    if !handle_has_tag(handle, ATTACHMENT_DATA_KEY_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidAttachmentDataKeyHandle);
    }
    attachment_key_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .get(&handle)
        .cloned()
        .ok_or(KelivoStatus::InvalidAttachmentDataKeyHandle)
}

fn close_attachment_key(handle: u64) -> Result<(), KelivoStatus> {
    if !handle_has_tag(handle, ATTACHMENT_DATA_KEY_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidAttachmentDataKeyHandle);
    }
    let removed = attachment_key_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .remove(&handle);
    drop(removed);
    Ok(())
}

fn attachment_error_status(error: AttachmentCryptoError) -> KelivoStatus {
    match error {
        AttachmentCryptoError::AuthenticationFailed | AttachmentCryptoError::ContextMismatch => {
            KelivoStatus::AttachmentAuthenticationFailed
        }
        AttachmentCryptoError::CryptoFailed => KelivoStatus::InternalState,
        AttachmentCryptoError::InputTooLarge => KelivoStatus::InputTooLarge,
        AttachmentCryptoError::InvalidEnvelope => KelivoStatus::AttachmentEnvelopeInvalid,
        AttachmentCryptoError::InvalidChunkGeometry
        | AttachmentCryptoError::InvalidEpoch
        | AttachmentCryptoError::InvalidUuidV4 => KelivoStatus::InvalidArgument,
        AttachmentCryptoError::RandomnessUnavailable => KelivoStatus::RandomSourceFailure,
    }
}

unsafe fn read_uuid_v4<const N: usize>(
    input: *const u8,
    length: usize,
) -> Result<[u8; N], KelivoStatus> {
    if input.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    if length != N {
        return Err(KelivoStatus::InvalidArgument);
    }
    let source = unsafe { core::slice::from_raw_parts(input, N) };
    source.try_into().map_err(|_| KelivoStatus::InvalidArgument)
}

unsafe fn read_attachment_context(
    user_id: *const u8,
    user_id_length: usize,
    attachment_id: *const u8,
    attachment_id_length: usize,
    key_epoch: u32,
) -> Result<crypto::AttachmentContext, KelivoStatus> {
    let user_id =
        unsafe { read_uuid_v4::<{ crypto::ATTACHMENT_ID_LENGTH }>(user_id, user_id_length) }?;
    let attachment_id = unsafe {
        read_uuid_v4::<{ crypto::ATTACHMENT_ID_LENGTH }>(attachment_id, attachment_id_length)
    }?;
    let user_id = device_crypto::UserId::new(user_id).map_err(|_| KelivoStatus::InvalidArgument)?;
    let attachment_id =
        crypto::AttachmentId::new(attachment_id).map_err(attachment_error_status)?;
    crypto::AttachmentContext::new(user_id, attachment_id, key_epoch)
        .map_err(attachment_error_status)
}

struct RawChunkContext {
    user_id: *const u8,
    user_id_length: usize,
    attachment_id: *const u8,
    attachment_id_length: usize,
    upload_id: *const u8,
    upload_id_length: usize,
    key_epoch: u32,
    chunk_index: u32,
    chunk_count: u32,
    total_plaintext_bytes: u64,
    plaintext_length: usize,
}

unsafe fn read_chunk_context(
    raw: RawChunkContext,
) -> Result<crypto::AttachmentChunkContext, KelivoStatus> {
    let plaintext_length =
        u32::try_from(raw.plaintext_length).map_err(|_| KelivoStatus::InputTooLarge)?;
    let attachment = unsafe {
        read_attachment_context(
            raw.user_id,
            raw.user_id_length,
            raw.attachment_id,
            raw.attachment_id_length,
            raw.key_epoch,
        )
    }?;
    let upload_id = unsafe {
        read_uuid_v4::<{ crypto::ATTACHMENT_ID_LENGTH }>(raw.upload_id, raw.upload_id_length)
    }?;
    let upload_id = crypto::AttachmentUploadId::new(upload_id).map_err(attachment_error_status)?;
    crypto::AttachmentChunkContext::new(
        attachment,
        upload_id,
        raw.chunk_index,
        raw.chunk_count,
        raw.total_plaintext_bytes,
        plaintext_length,
    )
    .map_err(attachment_error_status)
}

unsafe fn reset_handle_and_length(
    out_handle: *mut u64,
    out_length: *mut usize,
) -> Result<(), KelivoStatus> {
    unsafe {
        write_output(out_handle, INVALID_KEY_HANDLE)?;
        write_output(out_length, 0)?;
    }
    Ok(())
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 输出指针必须覆盖声明容量且彼此不重叠。容量不足时不会读取随机源或创建句柄。
pub unsafe extern "C" fn kelivo_attachment_data_key_generate(
    out_handle: *mut u64,
    out_attachment_id: *mut u8,
    out_attachment_id_capacity: usize,
    out_attachment_id_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { reset_handle_and_length(out_handle, out_attachment_id_length) } {
        return status.code();
    }
    if out_attachment_id_capacity < crypto::ATTACHMENT_ID_LENGTH {
        unsafe {
            write_output(out_attachment_id_length, crypto::ATTACHMENT_ID_LENGTH)
                .expect("已验证的附件标识长度输出必须可写")
        };
        return KelivoStatus::OutputBufferTooSmall.code();
    }
    if out_attachment_id.is_null() {
        return KelivoStatus::NullPointer.code();
    }

    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let attachment_id = match crypto::AttachmentId::generate(&mut rng) {
        Ok(id) => id,
        Err(error) => return attachment_error_status(error).code(),
    };
    let key = match crypto::AttachmentDataKey::generate(&mut rng) {
        Ok(key) => key,
        Err(error) => return attachment_error_status(error).code(),
    };
    let handle = match register_attachment_key(key) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };
    unsafe {
        core::ptr::copy_nonoverlapping(
            attachment_id.as_bytes().as_ptr(),
            out_attachment_id,
            crypto::ATTACHMENT_ID_LENGTH,
        );
        write_output(out_attachment_id_length, crypto::ATTACHMENT_ID_LENGTH)
            .expect("已验证的附件标识长度输出必须可写");
        write_output(out_handle, handle).expect("已验证的附件密钥句柄输出必须可写");
    }
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_attachment_data_key_handle_close(handle: u64) -> i32 {
    match close_attachment_key(handle) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出容量不足时只返回固定所需长度，不读取随机源。
pub unsafe extern "C" fn kelivo_attachment_data_key_wrap(
    ark_handle: u64,
    data_key_handle: u64,
    user_id: *const u8,
    user_id_length: usize,
    attachment_id: *const u8,
    attachment_id_length: usize,
    key_epoch: u32,
    out_wrapped_key: *mut u8,
    out_wrapped_key_capacity: usize,
    out_wrapped_key_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_wrapped_key_length, 0) } {
        return status.code();
    }
    let context = match unsafe {
        read_attachment_context(
            user_id,
            user_id_length,
            attachment_id,
            attachment_id_length,
            key_epoch,
        )
    } {
        Ok(context) => context,
        Err(status) => return status.code(),
    };
    let ark =
        match device_core::ark_for_account_handle(ark_handle, context.user_id, context.key_epoch) {
            Ok(ark) => ark,
            Err(KelivoStatus::InvalidArgument) => {
                return KelivoStatus::AttachmentAuthenticationFailed.code();
            }
            Err(status) => return status.code(),
        };
    let key = match attachment_key_for_handle(data_key_handle) {
        Ok(key) => key,
        Err(status) => return status.code(),
    };
    if out_wrapped_key_capacity < crypto::WRAPPED_ATTACHMENT_KEY_LENGTH {
        unsafe {
            write_output(
                out_wrapped_key_length,
                crypto::WRAPPED_ATTACHMENT_KEY_LENGTH,
            )
            .expect("已验证的包装密钥长度输出必须可写")
        };
        return KelivoStatus::OutputBufferTooSmall.code();
    }
    if out_wrapped_key.is_null() {
        return KelivoStatus::NullPointer.code();
    }
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let wrapped = match crypto::wrap_attachment_data_key(&mut rng, &ark, &key, context) {
        Ok(wrapped) => wrapped,
        Err(error) => return attachment_error_status(error).code(),
    };
    unsafe {
        core::ptr::copy_nonoverlapping(
            wrapped.as_ptr(),
            out_wrapped_key,
            crypto::WRAPPED_ATTACHMENT_KEY_LENGTH,
        );
        write_output(
            out_wrapped_key_length,
            crypto::WRAPPED_ATTACHMENT_KEY_LENGTH,
        )
        .expect("已验证的包装密钥长度输出必须可写");
    }
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度，`out_handle` 必须可写；失败时句柄保持为零。
pub unsafe extern "C" fn kelivo_attachment_data_key_unwrap(
    ark_handle: u64,
    user_id: *const u8,
    user_id_length: usize,
    attachment_id: *const u8,
    attachment_id_length: usize,
    key_epoch: u32,
    wrapped_key: *const u8,
    wrapped_key_length: usize,
    out_handle: *mut u64,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_handle, INVALID_KEY_HANDLE) } {
        return status.code();
    }
    let context = match unsafe {
        read_attachment_context(
            user_id,
            user_id_length,
            attachment_id,
            attachment_id_length,
            key_epoch,
        )
    } {
        Ok(context) => context,
        Err(status) => return status.code(),
    };
    let wrapped_key = match unsafe { read_input(wrapped_key, wrapped_key_length) } {
        Ok(wrapped) => wrapped,
        Err(status) => return status.code(),
    };
    let ark =
        match device_core::ark_for_account_handle(ark_handle, context.user_id, context.key_epoch) {
            Ok(ark) => ark,
            Err(KelivoStatus::InvalidArgument) => {
                return KelivoStatus::AttachmentAuthenticationFailed.code();
            }
            Err(status) => return status.code(),
        };
    let key = match crypto::unwrap_attachment_data_key(&ark, context, wrapped_key) {
        Ok(key) => key,
        Err(error) => return attachment_error_status(error).code(),
    };
    let handle = match register_attachment_key(key) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };
    unsafe {
        write_output(out_handle, handle).expect("已验证的附件密钥句柄输出必须可写")
    };
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 输入指针必须覆盖声明长度，输出指针必须覆盖声明容量且长度指针始终可写。
pub unsafe extern "C" fn kelivo_attachment_chunk_seal(
    data_key_handle: u64,
    user_id: *const u8,
    user_id_length: usize,
    attachment_id: *const u8,
    attachment_id_length: usize,
    upload_id: *const u8,
    upload_id_length: usize,
    key_epoch: u32,
    chunk_index: u32,
    chunk_count: u32,
    total_plaintext_bytes: u64,
    plaintext: *const u8,
    plaintext_length: usize,
    out_envelope: *mut u8,
    out_envelope_capacity: usize,
    out_envelope_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_envelope_length, 0) } {
        return status.code();
    }
    let context = match unsafe {
        read_chunk_context(RawChunkContext {
            user_id,
            user_id_length,
            attachment_id,
            attachment_id_length,
            upload_id,
            upload_id_length,
            key_epoch,
            chunk_index,
            chunk_count,
            total_plaintext_bytes,
            plaintext_length,
        })
    } {
        Ok(context) => context,
        Err(status) => return status.code(),
    };
    let key = match attachment_key_for_handle(data_key_handle) {
        Ok(key) => key,
        Err(status) => return status.code(),
    };
    let required = match crypto::attachment_chunk_envelope_size(context) {
        Ok(required) => required,
        Err(error) => return attachment_error_status(error).code(),
    };
    if out_envelope_capacity < required {
        unsafe {
            write_output(out_envelope_length, required).expect("已验证的附件块长度输出必须可写")
        };
        return KelivoStatus::OutputBufferTooSmall.code();
    }
    if out_envelope.is_null() {
        return KelivoStatus::NullPointer.code();
    }
    let plaintext = match unsafe { read_input(plaintext, plaintext_length) } {
        Ok(plaintext) => plaintext,
        Err(status) => return status.code(),
    };
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let envelope = match crypto::seal_attachment_chunk(&mut rng, &key, context, plaintext) {
        Ok(envelope) => envelope,
        Err(error) => return attachment_error_status(error).code(),
    };
    unsafe {
        write_bytes(
            out_envelope,
            out_envelope_capacity,
            &envelope,
            out_envelope_length,
        )
        .expect("已验证的附件块输出必须可写")
    };
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 输入指针必须覆盖声明长度，输出指针必须覆盖声明容量；认证失败不得写出明文。
pub unsafe extern "C" fn kelivo_attachment_chunk_open(
    data_key_handle: u64,
    user_id: *const u8,
    user_id_length: usize,
    attachment_id: *const u8,
    attachment_id_length: usize,
    upload_id: *const u8,
    upload_id_length: usize,
    key_epoch: u32,
    chunk_index: u32,
    chunk_count: u32,
    total_plaintext_bytes: u64,
    plaintext_length: usize,
    envelope: *const u8,
    envelope_length: usize,
    out_plaintext: *mut u8,
    out_plaintext_capacity: usize,
    out_plaintext_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_plaintext_length, 0) } {
        return status.code();
    }
    let context = match unsafe {
        read_chunk_context(RawChunkContext {
            user_id,
            user_id_length,
            attachment_id,
            attachment_id_length,
            upload_id,
            upload_id_length,
            key_epoch,
            chunk_index,
            chunk_count,
            total_plaintext_bytes,
            plaintext_length,
        })
    } {
        Ok(context) => context,
        Err(status) => return status.code(),
    };
    let envelope = match unsafe { read_input(envelope, envelope_length) } {
        Ok(envelope) => envelope,
        Err(status) => return status.code(),
    };
    let key = match attachment_key_for_handle(data_key_handle) {
        Ok(key) => key,
        Err(status) => return status.code(),
    };
    let required = match crypto::opened_attachment_chunk_size(context, envelope) {
        Ok(required) => required,
        Err(error) => return attachment_error_status(error).code(),
    };
    if out_plaintext_capacity < required {
        unsafe {
            write_output(out_plaintext_length, required).expect("已验证的附件明文长度输出必须可写")
        };
        return KelivoStatus::OutputBufferTooSmall.code();
    }
    if required > 0 && out_plaintext.is_null() {
        return KelivoStatus::NullPointer.code();
    }
    let plaintext = match crypto::open_attachment_chunk(&key, context, envelope) {
        Ok(plaintext) => plaintext,
        Err(error) => return attachment_error_status(error).code(),
    };
    unsafe {
        write_bytes(
            out_plaintext,
            out_plaintext_capacity,
            plaintext.as_slice(),
            out_plaintext_length,
        )
        .expect("已验证的附件明文输出必须可写")
    };
    KelivoStatus::Ok.code()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{kelivo_account_root_key_generate, kelivo_account_root_key_handle_close};

    fn uuid(seed: u8) -> [u8; 16] {
        let mut value = [seed; 16];
        value[6] = (value[6] & 0x0f) | 0x40;
        value[8] = (value[8] & 0x3f) | 0x80;
        value
    }

    fn generate_key() -> (u64, [u8; 16]) {
        let mut handle = 0;
        let mut attachment_id = [0_u8; 16];
        let mut length = 0;
        assert_eq!(
            unsafe {
                kelivo_attachment_data_key_generate(
                    &mut handle,
                    attachment_id.as_mut_ptr(),
                    attachment_id.len(),
                    &mut length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_ne!(handle, 0);
        assert_eq!(length, attachment_id.len());
        (handle, attachment_id)
    }

    #[test]
    fn attachment_handle_closes_idempotently_and_fails_closed_after_close() {
        let (handle, attachment_id) = generate_key();
        assert!(handle_has_tag(handle, ATTACHMENT_DATA_KEY_HANDLE_TAG));
        assert_eq!(attachment_id[6] & 0xf0, 0x40);
        assert_eq!(attachment_id[8] & 0xc0, 0x80);
        assert_eq!(
            kelivo_attachment_data_key_handle_close(handle),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_attachment_data_key_handle_close(handle),
            KelivoStatus::Ok.code()
        );

        let user_id = uuid(0x51);
        let upload_id = uuid(0x52);
        let plaintext = b"closed";
        let mut required = 0;
        assert_eq!(
            unsafe {
                kelivo_attachment_chunk_seal(
                    handle,
                    user_id.as_ptr(),
                    user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    upload_id.as_ptr(),
                    upload_id.len(),
                    1,
                    0,
                    1,
                    plaintext.len() as u64,
                    plaintext.as_ptr(),
                    plaintext.len(),
                    core::ptr::null_mut(),
                    0,
                    &mut required,
                )
            },
            KelivoStatus::InvalidAttachmentDataKeyHandle.code()
        );
        assert_eq!(required, 0);
    }

    #[test]
    fn wrapped_key_and_chunk_round_trip_through_c_abi() {
        let user_id = uuid(0x61);
        let mut ark = 0;
        assert_eq!(
            unsafe {
                kelivo_account_root_key_generate(user_id.as_ptr(), user_id.len(), 3, &mut ark)
            },
            KelivoStatus::Ok.code()
        );
        let (key, attachment_id) = generate_key();
        let upload_id = uuid(0x62);

        let mut wrapped_length = 0;
        assert_eq!(
            unsafe {
                kelivo_attachment_data_key_wrap(
                    ark,
                    key,
                    user_id.as_ptr(),
                    user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    3,
                    core::ptr::null_mut(),
                    0,
                    &mut wrapped_length,
                )
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        assert_eq!(wrapped_length, crypto::WRAPPED_ATTACHMENT_KEY_LENGTH);
        let mut wrapped = vec![0_u8; wrapped_length];
        assert_eq!(
            unsafe {
                kelivo_attachment_data_key_wrap(
                    ark,
                    key,
                    user_id.as_ptr(),
                    user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    3,
                    wrapped.as_mut_ptr(),
                    wrapped.len(),
                    &mut wrapped_length,
                )
            },
            KelivoStatus::Ok.code()
        );

        let other_user_id = uuid(0x63);
        let mut cross_account_wrapped = vec![0xa5_u8; wrapped.len()];
        let mut cross_account_wrapped_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_attachment_data_key_wrap(
                    ark,
                    key,
                    other_user_id.as_ptr(),
                    other_user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    3,
                    cross_account_wrapped.as_mut_ptr(),
                    cross_account_wrapped.len(),
                    &mut cross_account_wrapped_length,
                )
            },
            KelivoStatus::DeviceAuthenticationFailed.code()
        );
        assert_eq!(cross_account_wrapped_length, 0);

        let mut cross_account_handle = u64::MAX;
        assert_eq!(
            unsafe {
                kelivo_attachment_data_key_unwrap(
                    ark,
                    other_user_id.as_ptr(),
                    other_user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    3,
                    wrapped.as_ptr(),
                    wrapped.len(),
                    &mut cross_account_handle,
                )
            },
            KelivoStatus::DeviceAuthenticationFailed.code()
        );
        assert_eq!(cross_account_handle, INVALID_KEY_HANDLE);

        let mut reopened = 0;
        assert_eq!(
            unsafe {
                kelivo_attachment_data_key_unwrap(
                    ark,
                    user_id.as_ptr(),
                    user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    3,
                    wrapped.as_ptr(),
                    wrapped.len(),
                    &mut reopened,
                )
            },
            KelivoStatus::Ok.code()
        );
        let plaintext = b"native attachment chunk";
        let mut envelope_length = 0;
        assert_eq!(
            unsafe {
                kelivo_attachment_chunk_seal(
                    key,
                    user_id.as_ptr(),
                    user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    upload_id.as_ptr(),
                    upload_id.len(),
                    3,
                    0,
                    1,
                    plaintext.len() as u64,
                    plaintext.as_ptr(),
                    plaintext.len(),
                    core::ptr::null_mut(),
                    0,
                    &mut envelope_length,
                )
            },
            KelivoStatus::OutputBufferTooSmall.code()
        );
        let mut envelope = vec![0_u8; envelope_length];
        assert_eq!(
            unsafe {
                kelivo_attachment_chunk_seal(
                    key,
                    user_id.as_ptr(),
                    user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    upload_id.as_ptr(),
                    upload_id.len(),
                    3,
                    0,
                    1,
                    plaintext.len() as u64,
                    plaintext.as_ptr(),
                    plaintext.len(),
                    envelope.as_mut_ptr(),
                    envelope.len(),
                    &mut envelope_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        let mut opened = vec![0_u8; plaintext.len()];
        let mut opened_length = 0;
        assert_eq!(
            unsafe {
                kelivo_attachment_chunk_open(
                    reopened,
                    user_id.as_ptr(),
                    user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    upload_id.as_ptr(),
                    upload_id.len(),
                    3,
                    0,
                    1,
                    plaintext.len() as u64,
                    plaintext.len(),
                    envelope.as_ptr(),
                    envelope.len(),
                    opened.as_mut_ptr(),
                    opened.len(),
                    &mut opened_length,
                )
            },
            KelivoStatus::Ok.code()
        );
        assert_eq!(&opened[..opened_length], plaintext);

        let mut tampered = envelope.clone();
        *tampered.last_mut().expect("附件块信封非空") ^= 1;
        opened.fill(0xa5);
        opened_length = usize::MAX;
        assert_eq!(
            unsafe {
                kelivo_attachment_chunk_open(
                    reopened,
                    user_id.as_ptr(),
                    user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    upload_id.as_ptr(),
                    upload_id.len(),
                    3,
                    0,
                    1,
                    plaintext.len() as u64,
                    plaintext.len(),
                    tampered.as_ptr(),
                    tampered.len(),
                    opened.as_mut_ptr(),
                    opened.len(),
                    &mut opened_length,
                )
            },
            KelivoStatus::AttachmentAuthenticationFailed.code()
        );
        assert_eq!(opened_length, 0);
        assert!(opened.iter().all(|byte| *byte == 0xa5));

        let mut rejected_handle = u64::MAX;
        let mut tampered_wrapped = wrapped.clone();
        *tampered_wrapped.last_mut().expect("包装密钥信封非空") ^= 1;
        assert_eq!(
            unsafe {
                kelivo_attachment_data_key_unwrap(
                    ark,
                    user_id.as_ptr(),
                    user_id.len(),
                    attachment_id.as_ptr(),
                    attachment_id.len(),
                    3,
                    tampered_wrapped.as_ptr(),
                    tampered_wrapped.len(),
                    &mut rejected_handle,
                )
            },
            KelivoStatus::AttachmentAuthenticationFailed.code()
        );
        assert_eq!(rejected_handle, 0);

        assert_eq!(
            kelivo_attachment_data_key_handle_close(reopened),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_attachment_data_key_handle_close(key),
            KelivoStatus::Ok.code()
        );
        assert_eq!(
            kelivo_account_root_key_handle_close(ark),
            KelivoStatus::Ok.code()
        );
    }
}
