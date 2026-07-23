use std::{
    collections::HashMap,
    sync::{Arc, Mutex, OnceLock},
};

use kelivo_secure_core_protocol::{
    self as protocol, AccountBinding, ClientLoginState, ClientRegistrationState,
    CredentialResponse, Error as ProtocolError, RegistrationResponse,
};

use crate::{
    INVALID_OPAQUE_STATE_HANDLE, KelivoStatus, MAX_ACTIVE_OPAQUE_STATES,
    MAX_IN_FLIGHT_OPAQUE_FINISHES, OPAQUE_ACCOUNT_ID_SIZE, OPAQUE_CREDENTIAL_FINALIZATION_SIZE,
    OPAQUE_CREDENTIAL_REQUEST_SIZE, OPAQUE_CREDENTIAL_RESPONSE_SIZE,
    OPAQUE_REGISTRATION_REQUEST_SIZE, OPAQUE_REGISTRATION_RESPONSE_SIZE,
    OPAQUE_REGISTRATION_UPLOAD_SIZE, OPAQUE_STATE_HANDLE_TAG, handle_has_tag, issue_typed_handle,
    read_input, write_output,
};

enum OpaqueClientState {
    Registration(Box<ClientRegistrationState>),
    Login(Box<ClientLoginState>),
}

struct OpaqueClientRegistry {
    active: HashMap<u64, OpaqueClientState>,
    in_flight: usize,
    next_sequence: u64,
}

impl Default for OpaqueClientRegistry {
    fn default() -> Self {
        Self {
            active: HashMap::new(),
            in_flight: 0,
            next_sequence: 1,
        }
    }
}

struct OpaqueFinishPermit {
    registry: Arc<Mutex<OpaqueClientRegistry>>,
}

impl Drop for OpaqueFinishPermit {
    fn drop(&mut self) {
        // permit 的析构不能因此前 panic 造成永久配额泄漏；正式产物 panic=abort。
        let mut registry = match self.registry.lock() {
            Ok(registry) => registry,
            Err(poisoned) => poisoned.into_inner(),
        };
        registry.in_flight = registry
            .in_flight
            .checked_sub(1)
            .expect("OPAQUE 完成许可计数不得下溢");
    }
}

fn registry() -> &'static Arc<Mutex<OpaqueClientRegistry>> {
    static REGISTRY: OnceLock<Arc<Mutex<OpaqueClientRegistry>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Arc::new(Mutex::new(OpaqueClientRegistry::default())))
}

fn register_state_in(
    registry: &Arc<Mutex<OpaqueClientRegistry>>,
    state: OpaqueClientState,
) -> Result<u64, KelivoStatus> {
    let mut registry = registry.lock().map_err(|_| KelivoStatus::InternalState)?;

    let occupied = registry
        .active
        .len()
        .checked_add(registry.in_flight)
        .ok_or(KelivoStatus::HandleSpaceExhausted)?;
    if occupied >= MAX_ACTIVE_OPAQUE_STATES {
        return Err(KelivoStatus::TooManyActiveHandles);
    }
    let handle = issue_typed_handle(OPAQUE_STATE_HANDLE_TAG, &mut registry.next_sequence)?;
    let replaced = registry.active.insert(handle, state);
    debug_assert!(replaced.is_none());
    Ok(handle)
}

fn register_state(state: OpaqueClientState) -> Result<u64, KelivoStatus> {
    register_state_in(registry(), state)
}

fn close_state(handle: u64) -> Result<(), KelivoStatus> {
    if !handle_has_tag(handle, OPAQUE_STATE_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidOpaqueStateHandle);
    }

    let removed = registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .remove(&handle)
        .ok_or(KelivoStatus::InvalidOpaqueStateHandle)?;
    drop(removed);
    Ok(())
}

fn take_registration_state_from(
    registry: &Arc<Mutex<OpaqueClientRegistry>>,
    handle: u64,
) -> Result<(ClientRegistrationState, OpaqueFinishPermit), KelivoStatus> {
    if !handle_has_tag(handle, OPAQUE_STATE_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidOpaqueStateHandle);
    }
    let mut locked = registry.lock().map_err(|_| KelivoStatus::InternalState)?;
    let state = locked
        .active
        .remove(&handle)
        .ok_or(KelivoStatus::InvalidOpaqueStateHandle)?;
    match state {
        OpaqueClientState::Registration(state) => {
            if locked.in_flight >= MAX_IN_FLIGHT_OPAQUE_FINISHES {
                return Err(KelivoStatus::TooManyActiveHandles);
            }
            locked.in_flight = locked
                .in_flight
                .checked_add(1)
                .ok_or(KelivoStatus::HandleSpaceExhausted)?;
            drop(locked);
            Ok((
                *state,
                OpaqueFinishPermit {
                    registry: Arc::clone(registry),
                },
            ))
        }
        OpaqueClientState::Login(_) => Err(KelivoStatus::InvalidOpaqueStateHandle),
    }
}

fn take_registration_state(
    handle: u64,
) -> Result<(ClientRegistrationState, OpaqueFinishPermit), KelivoStatus> {
    take_registration_state_from(registry(), handle)
}

fn take_login_state_from(
    registry: &Arc<Mutex<OpaqueClientRegistry>>,
    handle: u64,
) -> Result<(ClientLoginState, OpaqueFinishPermit), KelivoStatus> {
    if !handle_has_tag(handle, OPAQUE_STATE_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidOpaqueStateHandle);
    }
    let mut locked = registry.lock().map_err(|_| KelivoStatus::InternalState)?;
    let state = locked
        .active
        .remove(&handle)
        .ok_or(KelivoStatus::InvalidOpaqueStateHandle)?;
    match state {
        OpaqueClientState::Login(state) => {
            if locked.in_flight >= MAX_IN_FLIGHT_OPAQUE_FINISHES {
                return Err(KelivoStatus::TooManyActiveHandles);
            }
            locked.in_flight = locked
                .in_flight
                .checked_add(1)
                .ok_or(KelivoStatus::HandleSpaceExhausted)?;
            drop(locked);
            Ok((
                *state,
                OpaqueFinishPermit {
                    registry: Arc::clone(registry),
                },
            ))
        }
        OpaqueClientState::Registration(_) => Err(KelivoStatus::InvalidOpaqueStateHandle),
    }
}

fn take_login_state(handle: u64) -> Result<(ClientLoginState, OpaqueFinishPermit), KelivoStatus> {
    take_login_state_from(registry(), handle)
}

fn protocol_error_status(error: ProtocolError) -> KelivoStatus {
    match error {
        ProtocolError::InvalidPasswordLength | ProtocolError::InvalidCredentialIdentifierLength => {
            KelivoStatus::InvalidArgument
        }
        ProtocolError::RandomnessUnavailable => KelivoStatus::RandomSourceFailure,
        ProtocolError::InvalidMagic
        | ProtocolError::UnsupportedFormatVersion(_)
        | ProtocolError::UnsupportedCipherSuite(_)
        | ProtocolError::UnsupportedPasswordProfile(_)
        | ProtocolError::UnsupportedFlags(_)
        | ProtocolError::UnexpectedObjectKind { .. }
        | ProtocolError::InvalidPayloadLength { .. }
        | ProtocolError::InvalidWireLength { .. } => KelivoStatus::OpaqueMessageInvalid,
        ProtocolError::Opaque(_) => KelivoStatus::OpaqueProtocolFailed,
        ProtocolError::InvalidPasswordProfileConfiguration
        | ProtocolError::InvalidServerLoginContinuationKeyLength { .. }
        | ProtocolError::InvalidServerLoginContinuationMagic
        | ProtocolError::UnsupportedServerLoginContinuationVersion(_)
        | ProtocolError::UnsupportedServerLoginContinuationCipherSuite(_)
        | ProtocolError::InvalidServerLoginContinuationLength { .. }
        | ProtocolError::ServerLoginContinuationAadTooLarge
        | ProtocolError::ServerLoginContinuationCrypto
        | ProtocolError::ServerLoginContinuationAuthenticationFailed => {
            // 客户端 ABI 不会处理服务端 continuation；若这些错误越过模块边界，属于内部接线错误。
            KelivoStatus::InternalState
        }
    }
}

fn require_message_length(message: &[u8], expected: usize) -> Result<(), KelivoStatus> {
    if message.len() == expected {
        Ok(())
    } else {
        Err(KelivoStatus::InternalState)
    }
}

unsafe fn reset_start_outputs(
    out_handle: *mut u64,
    out_message_length: *mut usize,
) -> Result<(), KelivoStatus> {
    let mut missing_output = false;
    if out_handle.is_null() {
        missing_output = true;
    } else {
        unsafe {
            out_handle.write(INVALID_OPAQUE_STATE_HANDLE);
        }
    }
    if out_message_length.is_null() {
        missing_output = true;
    } else {
        unsafe {
            out_message_length.write(0);
        }
    }

    if missing_output {
        Err(KelivoStatus::NullPointer)
    } else {
        Ok(())
    }
}

unsafe fn read_password<'a>(
    password: *const u8,
    password_length: usize,
) -> Result<&'a [u8], KelivoStatus> {
    if password_length > protocol::MAX_OPAQUE_INPUT_LENGTH {
        return Err(KelivoStatus::InputTooLarge);
    }
    let password = unsafe { read_input(password, password_length)? };
    if password.is_empty() {
        return Err(KelivoStatus::InvalidArgument);
    }
    Ok(password)
}

unsafe fn read_credential_identifier<'a>(
    credential_identifier: *const u8,
    credential_identifier_length: usize,
) -> Result<AccountBinding<'a>, KelivoStatus> {
    if credential_identifier_length != OPAQUE_ACCOUNT_ID_SIZE {
        return Err(KelivoStatus::InvalidAccountId);
    }
    let identifier = unsafe { read_input(credential_identifier, credential_identifier_length)? };
    if identifier[6] & 0xf0 != 0x40 || identifier[8] & 0xc0 != 0x80 {
        return Err(KelivoStatus::InvalidAccountId);
    }
    AccountBinding::new(identifier).map_err(protocol_error_status)
}

unsafe fn reset_message_length(out_message_length: *mut usize) -> Result<(), KelivoStatus> {
    unsafe { write_output(out_message_length, 0) }
}

/// # Safety
///
/// 所有指针都必须覆盖声明的可读或可写长度；输入字节区、输出字节区以及两个输出
/// 标量区必须彼此完全不重叠。失败时可写的句柄与长度输出会先归零。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_opaque_client_registration_start(
    password: *const u8,
    password_length: usize,
    out_state_handle: *mut u64,
    out_request: *mut u8,
    out_request_capacity: usize,
    out_request_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { reset_start_outputs(out_state_handle, out_request_length) } {
        return status.code();
    }
    if out_request.is_null() {
        return KelivoStatus::NullPointer.code();
    }
    if out_request_capacity < OPAQUE_REGISTRATION_REQUEST_SIZE {
        return KelivoStatus::OutputBufferTooSmall.code();
    }
    let password = match unsafe { read_password(password, password_length) } {
        Ok(password) => password,
        Err(status) => return status.code(),
    };
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(error) => return protocol_error_status(error).code(),
    };
    let start = match protocol::client_registration_start(&mut rng, password) {
        Ok(start) => start,
        Err(error) => return protocol_error_status(error).code(),
    };
    let (state, request) = start.into_parts();
    if let Err(status) =
        require_message_length(request.as_bytes(), OPAQUE_REGISTRATION_REQUEST_SIZE)
    {
        return status.code();
    }
    let handle = match register_state(OpaqueClientState::Registration(Box::new(state))) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };

    unsafe {
        core::ptr::copy_nonoverlapping(
            request.as_bytes().as_ptr(),
            out_request,
            request.as_bytes().len(),
        );
        // 两个输出指针已在函数入口验证，此处不会留下半写入的成功结果。
        write_output(out_request_length, OPAQUE_REGISTRATION_REQUEST_SIZE)
            .expect("已验证的长度输出必须可写");
        write_output(out_state_handle, handle).expect("已验证的句柄输出必须可写");
    }
    KelivoStatus::Ok.code()
}

/// # Safety
///
/// 所有指针都必须覆盖声明的可读或可写长度；所有输入字节区、输出字节区与输出
/// 长度标量区必须彼此完全不重叠。只要长度输出可写，本函数会先将其归零；有效
/// 状态句柄在本次调用中被单次消费，成功或失败后均不可复用。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_opaque_client_registration_finish(
    state_handle: u64,
    password: *const u8,
    password_length: usize,
    response: *const u8,
    response_length: usize,
    credential_identifier: *const u8,
    credential_identifier_length: usize,
    out_upload: *mut u8,
    out_upload_capacity: usize,
    out_upload_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { reset_message_length(out_upload_length) } {
        return status.code();
    }
    let (state, _finish_permit) = match take_registration_state(state_handle) {
        Ok(state_and_permit) => state_and_permit,
        Err(status) => return status.code(),
    };
    if out_upload.is_null() {
        return KelivoStatus::NullPointer.code();
    }
    if out_upload_capacity < OPAQUE_REGISTRATION_UPLOAD_SIZE {
        return KelivoStatus::OutputBufferTooSmall.code();
    }
    let password = match unsafe { read_password(password, password_length) } {
        Ok(password) => password,
        Err(status) => return status.code(),
    };
    let binding = match unsafe {
        read_credential_identifier(credential_identifier, credential_identifier_length)
    } {
        Ok(binding) => binding,
        Err(status) => return status.code(),
    };
    if response_length != OPAQUE_REGISTRATION_RESPONSE_SIZE {
        return KelivoStatus::OpaqueMessageInvalid.code();
    }
    let response = match unsafe { read_input(response, response_length) } {
        Ok(response) => match RegistrationResponse::from_bytes(response) {
            Ok(response) => response,
            Err(error) => return protocol_error_status(error).code(),
        },
        Err(status) => return status.code(),
    };
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(error) => return protocol_error_status(error).code(),
    };
    let upload =
        match protocol::client_registration_finish(&mut rng, state, password, response, binding) {
            Ok(finish) => finish.into_upload(),
            Err(error) => return protocol_error_status(error).code(),
        };
    if let Err(status) = require_message_length(upload.as_bytes(), OPAQUE_REGISTRATION_UPLOAD_SIZE)
    {
        return status.code();
    }

    unsafe {
        core::ptr::copy_nonoverlapping(
            upload.as_bytes().as_ptr(),
            out_upload,
            upload.as_bytes().len(),
        );
        write_output(out_upload_length, OPAQUE_REGISTRATION_UPLOAD_SIZE)
            .expect("已验证的长度输出必须可写");
    }
    KelivoStatus::Ok.code()
}

/// # Safety
///
/// 所有指针都必须覆盖声明的可读或可写长度；输入字节区、输出字节区以及两个输出
/// 标量区必须彼此完全不重叠。失败时可写的句柄与长度输出会先归零。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_opaque_client_login_start(
    password: *const u8,
    password_length: usize,
    out_state_handle: *mut u64,
    out_request: *mut u8,
    out_request_capacity: usize,
    out_request_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { reset_start_outputs(out_state_handle, out_request_length) } {
        return status.code();
    }
    if out_request.is_null() {
        return KelivoStatus::NullPointer.code();
    }
    if out_request_capacity < OPAQUE_CREDENTIAL_REQUEST_SIZE {
        return KelivoStatus::OutputBufferTooSmall.code();
    }
    let password = match unsafe { read_password(password, password_length) } {
        Ok(password) => password,
        Err(status) => return status.code(),
    };
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(error) => return protocol_error_status(error).code(),
    };
    let start = match protocol::client_login_start(&mut rng, password) {
        Ok(start) => start,
        Err(error) => return protocol_error_status(error).code(),
    };
    let (state, request) = start.into_parts();
    if let Err(status) = require_message_length(request.as_bytes(), OPAQUE_CREDENTIAL_REQUEST_SIZE)
    {
        return status.code();
    }
    let handle = match register_state(OpaqueClientState::Login(Box::new(state))) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };

    unsafe {
        core::ptr::copy_nonoverlapping(
            request.as_bytes().as_ptr(),
            out_request,
            request.as_bytes().len(),
        );
        write_output(out_request_length, OPAQUE_CREDENTIAL_REQUEST_SIZE)
            .expect("已验证的长度输出必须可写");
        write_output(out_state_handle, handle).expect("已验证的句柄输出必须可写");
    }
    KelivoStatus::Ok.code()
}

/// # Safety
///
/// 所有指针都必须覆盖声明的可读或可写长度；所有输入字节区、输出字节区与输出
/// 长度标量区必须彼此完全不重叠。只要长度输出可写，本函数会先将其归零；有效
/// 状态句柄在本次调用中被单次消费，成功或失败后均不可复用。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kelivo_opaque_client_login_finish(
    state_handle: u64,
    password: *const u8,
    password_length: usize,
    response: *const u8,
    response_length: usize,
    credential_identifier: *const u8,
    credential_identifier_length: usize,
    out_finalization: *mut u8,
    out_finalization_capacity: usize,
    out_finalization_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { reset_message_length(out_finalization_length) } {
        return status.code();
    }
    let (state, _finish_permit) = match take_login_state(state_handle) {
        Ok(state_and_permit) => state_and_permit,
        Err(status) => return status.code(),
    };
    if out_finalization.is_null() {
        return KelivoStatus::NullPointer.code();
    }
    if out_finalization_capacity < OPAQUE_CREDENTIAL_FINALIZATION_SIZE {
        return KelivoStatus::OutputBufferTooSmall.code();
    }
    let password = match unsafe { read_password(password, password_length) } {
        Ok(password) => password,
        Err(status) => return status.code(),
    };
    let binding = match unsafe {
        read_credential_identifier(credential_identifier, credential_identifier_length)
    } {
        Ok(binding) => binding,
        Err(status) => return status.code(),
    };
    if response_length != OPAQUE_CREDENTIAL_RESPONSE_SIZE {
        return KelivoStatus::OpaqueMessageInvalid.code();
    }
    let response = match unsafe { read_input(response, response_length) } {
        Ok(response) => match CredentialResponse::from_bytes(response) {
            Ok(response) => response,
            Err(error) => return protocol_error_status(error).code(),
        },
        Err(status) => return status.code(),
    };
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(error) => return protocol_error_status(error).code(),
    };
    let finalization =
        match protocol::client_login_finish(&mut rng, state, password, response, binding) {
            Ok(finish) => finish.into_finalization(),
            Err(error) => return protocol_error_status(error).code(),
        };
    if let Err(status) =
        require_message_length(finalization.as_bytes(), OPAQUE_CREDENTIAL_FINALIZATION_SIZE)
    {
        return status.code();
    }

    unsafe {
        core::ptr::copy_nonoverlapping(
            finalization.as_bytes().as_ptr(),
            out_finalization,
            finalization.as_bytes().len(),
        );
        write_output(out_finalization_length, OPAQUE_CREDENTIAL_FINALIZATION_SIZE)
            .expect("已验证的长度输出必须可写");
    }
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_opaque_client_state_close(handle: u64) -> i32 {
    match close_state(handle) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn registration_state(seed: u8) -> OpaqueClientState {
        let mut rng = protocol::system_rng().expect("测试随机源应可用");
        let password = [seed.max(1); 16];
        let (state, _) = protocol::client_registration_start(&mut rng, &password)
            .expect("注册状态应创建")
            .into_parts();
        OpaqueClientState::Registration(Box::new(state))
    }

    #[test]
    fn active_and_in_flight_states_share_one_hard_limit() {
        let registry = Arc::new(Mutex::new(OpaqueClientRegistry::default()));
        registry.lock().expect("测试注册表锁应可用").in_flight = MAX_ACTIVE_OPAQUE_STATES - 1;

        register_state_in(&registry, registration_state(1))
            .expect("总占用低于上限时应允许最后一个状态");
        assert_eq!(
            register_state_in(&registry, registration_state(2)),
            Err(KelivoStatus::TooManyActiveHandles)
        );
        let locked = registry.lock().expect("测试注册表锁应可用");
        assert_eq!(locked.active.len(), 1);
        assert_eq!(locked.in_flight, MAX_ACTIVE_OPAQUE_STATES - 1);
    }

    #[test]
    fn only_one_finish_permit_is_allowed_and_released_capacity_can_be_reused() {
        let registry = Arc::new(Mutex::new(OpaqueClientRegistry::default()));
        let first_handle = register_state_in(&registry, registration_state(3)).expect("状态应注册");
        let second_handle =
            register_state_in(&registry, registration_state(4)).expect("状态应注册");
        let (_first_state, first_permit) =
            take_registration_state_from(&registry, first_handle).expect("首个状态应取得许可");
        assert_eq!(registry.lock().expect("测试注册表锁应可用").in_flight, 1);
        assert!(matches!(
            take_registration_state_from(&registry, second_handle),
            Err(KelivoStatus::TooManyActiveHandles)
        ));
        assert_eq!(registry.lock().expect("测试注册表锁应可用").active.len(), 0);
        drop(first_permit);
        assert_eq!(registry.lock().expect("测试注册表锁应可用").in_flight, 0);

        let third_handle = register_state_in(&registry, registration_state(5)).expect("状态应注册");
        let (_third_state, third_permit) =
            take_registration_state_from(&registry, third_handle).expect("释放后应再次取得许可");
        assert_eq!(registry.lock().expect("测试注册表锁应可用").in_flight, 1);
        drop(third_permit);
        assert_eq!(registry.lock().expect("测试注册表锁应可用").in_flight, 0);
    }

    #[test]
    fn finish_permit_is_released_on_early_failure() {
        let registry = Arc::new(Mutex::new(OpaqueClientRegistry::default()));
        let failure_handle =
            register_state_in(&registry, registration_state(6)).expect("状态应注册");
        fn fail_after_take(
            registry: &Arc<Mutex<OpaqueClientRegistry>>,
            handle: u64,
        ) -> Result<(), KelivoStatus> {
            let (_state, _permit) = take_registration_state_from(registry, handle)?;
            Err(KelivoStatus::InvalidArgument)
        }
        assert_eq!(
            fail_after_take(&registry, failure_handle),
            Err(KelivoStatus::InvalidArgument)
        );
        let locked = registry.lock().expect("测试注册表锁应可用");
        assert_eq!(locked.active.len(), 0);
        assert_eq!(locked.in_flight, 0);
    }

    #[test]
    #[should_panic(expected = "OPAQUE 完成许可计数不得下溢")]
    fn finish_permit_underflow_fails_closed() {
        drop(OpaqueFinishPermit {
            registry: Arc::new(Mutex::new(OpaqueClientRegistry::default())),
        });
    }
}
