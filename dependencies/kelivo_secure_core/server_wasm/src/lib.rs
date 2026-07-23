use std::collections::BTreeMap;
use std::sync::{Mutex, MutexGuard, OnceLock};

use chacha20::{
    ChaCha20Rng as ZeroizingChaCha20Rng,
    rand_core::{SeedableRng as SeedableRngV10, TryRng},
};
use kelivo_secure_core_protocol::{
    AccountBinding, CREDENTIAL_FINALIZATION_LENGTH, CREDENTIAL_REQUEST_LENGTH,
    CREDENTIAL_RESPONSE_LENGTH, CredentialFinalization, CredentialRequest,
    REGISTRATION_RECORD_LENGTH, REGISTRATION_REQUEST_LENGTH, REGISTRATION_RESPONSE_LENGTH,
    REGISTRATION_UPLOAD_LENGTH, RegistrationRecord, RegistrationRequest, RegistrationUpload,
    SERVER_LOGIN_CONTINUATION_KEY_LENGTH, SERVER_LOGIN_CONTINUATION_LENGTH, SERVER_SETUP_LENGTH,
    ServerLoginContinuation, ServerLoginContinuationKey, ServerSetup, server_login_finish_sealed,
    server_login_start_sealed, server_registration_finish, server_registration_start,
};
use rand_core::{CryptoRng, Error as RandomError, RngCore};
use zeroize::{ZeroizeOnDrop, Zeroizing};

pub const ABI_VERSION: u32 = 1;
pub const STATUS_OK: i32 = 0;
pub const STATUS_INVALID_BUFFER_HANDLE: i32 = -1;
pub const STATUS_UNSUPPORTED_BUFFER_LENGTH: i32 = -2;
pub const STATUS_TOO_MANY_ACTIVE_BUFFERS: i32 = -3;
pub const STATUS_HANDLE_SPACE_EXHAUSTED: i32 = -4;
pub const STATUS_PROTOCOL_FAILED: i32 = -5;
pub const STATUS_AUTHENTICATION_FAILED: i32 = -6;
pub const STATUS_INTERNAL_STATE: i32 = -7;
pub const STATUS_INVALID_CONTINUATION_AAD: i32 = -8;

const INVALID_BUFFER_HANDLE: i32 = 0;
pub const MAX_ACTIVE_BUFFERS: usize = 64;
const MAX_BUFFER_HANDLE: u32 = i32::MAX as u32;
pub const ACCOUNT_ID_LENGTH: usize = 16;
pub const RANDOM_SEED_LENGTH: usize = 32;
pub const SERVER_LOGIN_OUTPUT_LENGTH: usize = 512;
pub const CONTINUATION_AAD_LENGTH: usize = 48;

const CONTINUATION_AAD_MAGIC: &[u8; 4] = b"KOAD";
const CONTINUATION_AAD_VERSION: u16 = 1;
const CONTINUATION_AAD_FLAGS: u16 = 0;
const CONTINUATION_AAD_ATTEMPT_ID_START: usize = 8;
const CONTINUATION_AAD_ACCOUNT_ID_START: usize = 24;
const CONTINUATION_AAD_EXPIRES_AT_START: usize = 40;
const SUPPORTED_BUFFER_LENGTHS: [usize; 14] = [
    ACCOUNT_ID_LENGTH,
    RANDOM_SEED_LENGTH,
    SERVER_SETUP_LENGTH,
    REGISTRATION_REQUEST_LENGTH,
    REGISTRATION_RESPONSE_LENGTH,
    REGISTRATION_UPLOAD_LENGTH,
    REGISTRATION_RECORD_LENGTH,
    CREDENTIAL_REQUEST_LENGTH,
    CREDENTIAL_RESPONSE_LENGTH,
    CREDENTIAL_FINALIZATION_LENGTH,
    SERVER_LOGIN_CONTINUATION_KEY_LENGTH,
    SERVER_LOGIN_CONTINUATION_LENGTH,
    CONTINUATION_AAD_LENGTH,
    SERVER_LOGIN_OUTPUT_LENGTH,
];

const _: () = {
    assert!(
        SERVER_LOGIN_OUTPUT_LENGTH == CREDENTIAL_RESPONSE_LENGTH + SERVER_LOGIN_CONTINUATION_LENGTH
    );
    assert!(RANDOM_SEED_LENGTH == SERVER_LOGIN_CONTINUATION_KEY_LENGTH);
};

type SecretBuffer = Zeroizing<Box<[u8]>>;

struct BufferSpec {
    handle: u32,
    expected_length: usize,
    optional: bool,
}

// Worker 传入的随机种子必须扩展为可在析构时清除 core 与预生成块的 RNG。
struct ProtocolRng(ZeroizingChaCha20Rng);

impl ProtocolRng {
    fn from_bytes(bytes: &[u8]) -> Result<Self, i32> {
        if bytes.len() != RANDOM_SEED_LENGTH {
            return Err(STATUS_UNSUPPORTED_BUFFER_LENGTH);
        }
        let mut seed = Zeroizing::new([0_u8; RANDOM_SEED_LENGTH]);
        seed.copy_from_slice(bytes);
        Ok(Self(ZeroizingChaCha20Rng::from_seed(*seed)))
    }
}

impl RngCore for ProtocolRng {
    fn next_u32(&mut self) -> u32 {
        match self.0.try_next_u32() {
            Ok(value) => value,
            Err(error) => match error {},
        }
    }

    fn next_u64(&mut self) -> u64 {
        match self.0.try_next_u64() {
            Ok(value) => value,
            Err(error) => match error {},
        }
    }

    fn fill_bytes(&mut self, destination: &mut [u8]) {
        match self.0.try_fill_bytes(destination) {
            Ok(()) => {}
            Err(error) => match error {},
        }
    }

    fn try_fill_bytes(&mut self, destination: &mut [u8]) -> Result<(), RandomError> {
        match self.0.try_fill_bytes(destination) {
            Ok(()) => Ok(()),
            Err(error) => match error {},
        }
    }
}

impl CryptoRng for ProtocolRng {}
impl ZeroizeOnDrop for ProtocolRng {}

struct BufferRegistry {
    active: BTreeMap<u32, Zeroizing<Box<[u8]>>>,
    next_handle: u32,
}

impl BufferRegistry {
    fn new() -> Self {
        Self {
            active: BTreeMap::new(),
            next_handle: 1,
        }
    }

    fn open(&mut self, length: usize) -> Result<u32, i32> {
        if !is_supported_buffer_length(length) {
            return Err(STATUS_UNSUPPORTED_BUFFER_LENGTH);
        }
        if self.active.len() >= MAX_ACTIVE_BUFFERS {
            return Err(STATUS_TOO_MANY_ACTIVE_BUFFERS);
        }
        self.insert(Zeroizing::new(vec![0_u8; length].into_boxed_slice()))
    }

    fn insert(&mut self, buffer: SecretBuffer) -> Result<u32, i32> {
        if self.active.len() >= MAX_ACTIVE_BUFFERS {
            return Err(STATUS_TOO_MANY_ACTIVE_BUFFERS);
        }
        if self.next_handle > MAX_BUFFER_HANDLE {
            return Err(STATUS_HANDLE_SPACE_EXHAUSTED);
        }

        let handle = self.next_handle;
        self.next_handle = self
            .next_handle
            .checked_add(1)
            .ok_or(STATUS_HANDLE_SPACE_EXHAUSTED)?;
        let replaced = self.active.insert(handle, buffer);
        if replaced.is_some() {
            return Err(STATUS_HANDLE_SPACE_EXHAUSTED);
        }
        Ok(handle)
    }
}

fn is_supported_buffer_length(length: usize) -> bool {
    SUPPORTED_BUFFER_LENGTHS.contains(&length)
}

fn registry() -> &'static Mutex<BufferRegistry> {
    static REGISTRY: OnceLock<Mutex<BufferRegistry>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(BufferRegistry::new()))
}

fn lock_registry() -> Result<MutexGuard<'static, BufferRegistry>, i32> {
    registry().lock().map_err(|_| STATUS_INTERNAL_STATE)
}

fn consume_buffers(specs: &[BufferSpec]) -> Result<Vec<Option<SecretBuffer>>, i32> {
    let mut registry = lock_registry()?;
    let mut consumed = Vec::with_capacity(specs.len());
    let mut failure = None;

    for spec in specs {
        if spec.handle == INVALID_BUFFER_HANDLE as u32 {
            if spec.optional {
                consumed.push(None);
            } else {
                failure.get_or_insert(STATUS_INVALID_BUFFER_HANDLE);
                consumed.push(None);
            }
            continue;
        }

        match registry.active.remove(&spec.handle) {
            Some(buffer) => {
                if buffer.len() != spec.expected_length {
                    failure.get_or_insert(STATUS_UNSUPPORTED_BUFFER_LENGTH);
                }
                consumed.push(Some(buffer));
            }
            None => {
                failure.get_or_insert(STATUS_INVALID_BUFFER_HANDLE);
                consumed.push(None);
            }
        }
    }
    drop(registry);

    if let Some(status) = failure {
        drop(consumed);
        return Err(status);
    }
    Ok(consumed)
}

fn register_output(bytes: &[u8]) -> Result<i32, i32> {
    if !is_supported_buffer_length(bytes.len()) {
        return Err(STATUS_UNSUPPORTED_BUFFER_LENGTH);
    }
    let mut output = Zeroizing::new(vec![0_u8; bytes.len()].into_boxed_slice());
    output.copy_from_slice(bytes);
    register_output_buffer(output)
}

fn register_output_buffer(output: SecretBuffer) -> Result<i32, i32> {
    let handle = lock_registry()?.insert(output)?;
    i32::try_from(handle).map_err(|_| STATUS_HANDLE_SPACE_EXHAUSTED)
}

fn protocol_failure<T>(_: T) -> i32 {
    STATUS_PROTOCOL_FAILED
}

fn is_uuid_v4(bytes: &[u8]) -> bool {
    bytes.len() == ACCOUNT_ID_LENGTH && bytes[6] & 0xf0 == 0x40 && bytes[8] & 0xc0 == 0x80
}

fn validate_continuation_aad(aad: &[u8], account_id: &[u8]) -> Result<(), i32> {
    if aad.len() != CONTINUATION_AAD_LENGTH || !is_uuid_v4(account_id) {
        return Err(STATUS_INVALID_CONTINUATION_AAD);
    }

    // API 层负责拼装 AAD，Wasm 再固定校验格式，避免调用方削弱账户绑定或引入版本歧义。
    let version = u16::from_be_bytes([aad[4], aad[5]]);
    let flags = u16::from_be_bytes([aad[6], aad[7]]);
    let attempt_id = &aad[CONTINUATION_AAD_ATTEMPT_ID_START..CONTINUATION_AAD_ACCOUNT_ID_START];
    let aad_account_id = &aad[CONTINUATION_AAD_ACCOUNT_ID_START..CONTINUATION_AAD_EXPIRES_AT_START];
    let expires_at_ms = u64::from_be_bytes(
        aad[CONTINUATION_AAD_EXPIRES_AT_START..CONTINUATION_AAD_LENGTH]
            .try_into()
            .map_err(|_| STATUS_INVALID_CONTINUATION_AAD)?,
    );

    if &aad[..CONTINUATION_AAD_MAGIC.len()] != CONTINUATION_AAD_MAGIC
        || version != CONTINUATION_AAD_VERSION
        || flags != CONTINUATION_AAD_FLAGS
        || !is_uuid_v4(attempt_id)
        || !is_uuid_v4(aad_account_id)
        || aad_account_id != account_id
        || expires_at_ms == 0
    {
        return Err(STATUS_INVALID_CONTINUATION_AAD);
    }
    Ok(())
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_opaque_server_abi_version() -> u32 {
    ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_opaque_server_buffer_open(length: usize) -> i32 {
    lock_registry()
        .and_then(|mut registry| registry.open(length))
        .and_then(|handle| i32::try_from(handle).map_err(|_| STATUS_HANDLE_SPACE_EXHAUSTED))
        .unwrap_or_else(|status| status)
}

/// 地址仅在句柄未被关闭或消费时有效；调用方不得并发关闭后继续读写该地址。
#[unsafe(no_mangle)]
pub extern "C" fn kelivo_opaque_server_buffer_pointer(handle: u32) -> usize {
    let Ok(mut registry) = lock_registry() else {
        return 0;
    };
    registry
        .active
        .get_mut(&handle)
        .map_or(0, |buffer| buffer.as_mut_ptr() as usize)
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_opaque_server_buffer_length(handle: u32) -> usize {
    let Ok(registry) = lock_registry() else {
        return 0;
    };
    registry
        .active
        .get(&handle)
        .map_or(0, |buffer| buffer.len())
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_opaque_server_buffer_close(handle: u32) -> i32 {
    let mut registry = match lock_registry() {
        Ok(registry) => registry,
        Err(status) => return status,
    };
    let Some(buffer) = registry.active.remove(&handle) else {
        return STATUS_INVALID_BUFFER_HANDLE;
    };
    drop(buffer);
    STATUS_OK
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_opaque_server_registration_start(
    server_setup_handle: u32,
    registration_request_handle: u32,
    account_id_handle: u32,
) -> i32 {
    let inputs = match consume_buffers(&[
        BufferSpec {
            handle: server_setup_handle,
            expected_length: SERVER_SETUP_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: registration_request_handle,
            expected_length: REGISTRATION_REQUEST_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: account_id_handle,
            expected_length: ACCOUNT_ID_LENGTH,
            optional: false,
        },
    ]) {
        Ok(inputs) => inputs,
        Err(status) => return status,
    };
    let [Some(server_setup), Some(request), Some(account_id)] = inputs.as_slice() else {
        return STATUS_INVALID_BUFFER_HANDLE;
    };

    let result = (|| {
        let server_setup = ServerSetup::from_bytes(server_setup).map_err(protocol_failure)?;
        let request = RegistrationRequest::from_bytes(request).map_err(protocol_failure)?;
        let binding = AccountBinding::new(account_id).map_err(protocol_failure)?;
        let response =
            server_registration_start(&server_setup, request, binding).map_err(protocol_failure)?;
        if response.as_bytes().len() != REGISTRATION_RESPONSE_LENGTH {
            return Err(STATUS_PROTOCOL_FAILED);
        }
        register_output(response.as_bytes())
    })();
    result.unwrap_or_else(|status| status)
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_opaque_server_registration_finish(registration_upload_handle: u32) -> i32 {
    let inputs = match consume_buffers(&[BufferSpec {
        handle: registration_upload_handle,
        expected_length: REGISTRATION_UPLOAD_LENGTH,
        optional: false,
    }]) {
        Ok(inputs) => inputs,
        Err(status) => return status,
    };
    let [Some(upload)] = inputs.as_slice() else {
        return STATUS_INVALID_BUFFER_HANDLE;
    };

    let result = (|| {
        let upload = RegistrationUpload::from_bytes(upload).map_err(protocol_failure)?;
        let record = server_registration_finish(upload).map_err(protocol_failure)?;
        if record.as_bytes().len() != REGISTRATION_RECORD_LENGTH {
            return Err(STATUS_PROTOCOL_FAILED);
        }
        register_output(record.as_bytes())
    })();
    result.unwrap_or_else(|status| status)
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_opaque_server_login_start(
    random_seed_handle: u32,
    server_setup_handle: u32,
    registration_record_handle: u32,
    credential_request_handle: u32,
    account_id_handle: u32,
    continuation_key_handle: u32,
    continuation_aad_handle: u32,
) -> i32 {
    let inputs = match consume_buffers(&[
        BufferSpec {
            handle: random_seed_handle,
            expected_length: RANDOM_SEED_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: server_setup_handle,
            expected_length: SERVER_SETUP_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: registration_record_handle,
            expected_length: REGISTRATION_RECORD_LENGTH,
            optional: true,
        },
        BufferSpec {
            handle: credential_request_handle,
            expected_length: CREDENTIAL_REQUEST_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: account_id_handle,
            expected_length: ACCOUNT_ID_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: continuation_key_handle,
            expected_length: SERVER_LOGIN_CONTINUATION_KEY_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: continuation_aad_handle,
            expected_length: CONTINUATION_AAD_LENGTH,
            optional: false,
        },
    ]) {
        Ok(inputs) => inputs,
        Err(status) => return status,
    };
    let [
        Some(random_seed),
        Some(server_setup),
        registration_record,
        Some(request),
        Some(account_id),
        Some(continuation_key),
        Some(continuation_aad),
    ] = inputs.as_slice()
    else {
        return STATUS_INVALID_BUFFER_HANDLE;
    };

    let result = (|| {
        validate_continuation_aad(continuation_aad, account_id)?;
        let mut rng = ProtocolRng::from_bytes(random_seed)?;
        let server_setup = ServerSetup::from_bytes(server_setup).map_err(protocol_failure)?;
        let registration = match registration_record {
            Some(record) => Some(RegistrationRecord::from_bytes(record).map_err(protocol_failure)?),
            None => None,
        };
        let request = CredentialRequest::from_bytes(request).map_err(protocol_failure)?;
        let binding = AccountBinding::new(account_id).map_err(protocol_failure)?;
        let continuation_key =
            ServerLoginContinuationKey::from_bytes(continuation_key).map_err(protocol_failure)?;
        let (response, continuation) = server_login_start_sealed(
            &mut rng,
            &server_setup,
            registration.as_ref(),
            request,
            binding,
            &continuation_key,
            continuation_aad,
        )
        .map_err(protocol_failure)?
        .into_parts();

        // 单缓冲区避免跨 Wasm 边界返回复合值：先响应，再拼接密封 continuation。
        let mut output = Zeroizing::new(vec![0_u8; SERVER_LOGIN_OUTPUT_LENGTH].into_boxed_slice());
        output[..CREDENTIAL_RESPONSE_LENGTH].copy_from_slice(response.as_bytes());
        output[CREDENTIAL_RESPONSE_LENGTH..].copy_from_slice(continuation.as_bytes());
        register_output_buffer(output)
    })();
    result.unwrap_or_else(|status| status)
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_opaque_server_login_finish(
    continuation_handle: u32,
    continuation_key_handle: u32,
    continuation_aad_handle: u32,
    credential_finalization_handle: u32,
    account_id_handle: u32,
) -> i32 {
    let inputs = match consume_buffers(&[
        BufferSpec {
            handle: continuation_handle,
            expected_length: SERVER_LOGIN_CONTINUATION_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: continuation_key_handle,
            expected_length: SERVER_LOGIN_CONTINUATION_KEY_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: continuation_aad_handle,
            expected_length: CONTINUATION_AAD_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: credential_finalization_handle,
            expected_length: CREDENTIAL_FINALIZATION_LENGTH,
            optional: false,
        },
        BufferSpec {
            handle: account_id_handle,
            expected_length: ACCOUNT_ID_LENGTH,
            optional: false,
        },
    ]) {
        Ok(inputs) => inputs,
        Err(_) => return STATUS_AUTHENTICATION_FAILED,
    };
    let [
        Some(continuation),
        Some(continuation_key),
        Some(continuation_aad),
        Some(finalization),
        Some(account_id),
    ] = inputs.as_slice()
    else {
        return STATUS_AUTHENTICATION_FAILED;
    };

    let result: Result<(), ()> = (|| {
        validate_continuation_aad(continuation_aad, account_id).map_err(|_| ())?;
        let continuation = ServerLoginContinuation::from_bytes(continuation).map_err(|_| ())?;
        let continuation_key =
            ServerLoginContinuationKey::from_bytes(continuation_key).map_err(|_| ())?;
        let finalization = CredentialFinalization::from_bytes(finalization).map_err(|_| ())?;
        let binding = AccountBinding::new(account_id).map_err(|_| ())?;
        server_login_finish_sealed(
            continuation,
            &continuation_key,
            continuation_aad,
            finalization,
            binding,
        )
        .map_err(|_| ())
    })();
    if result.is_ok() {
        STATUS_OK
    } else {
        STATUS_AUTHENTICATION_FAILED
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use kelivo_secure_core_protocol::{
        AccountBinding, CredentialResponse, RegistrationRecord, RegistrationResponse,
        client_login_finish, client_login_start, client_registration_finish,
        client_registration_start, generate_server_setup,
    };
    use rand_chacha::ChaCha20Rng;
    use rand_core::SeedableRng;

    fn test_guard() -> MutexGuard<'static, ()> {
        static TEST_GUARD: OnceLock<Mutex<()>> = OnceLock::new();
        TEST_GUARD
            .get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    fn open_buffer(bytes: &[u8]) -> u32 {
        let handle = kelivo_opaque_server_buffer_open(bytes.len());
        assert!(handle > 0, "测试输入缓冲区应成功分配");
        let handle = handle as u32;
        let pointer = kelivo_opaque_server_buffer_pointer(handle);
        assert_ne!(pointer, 0, "测试输入缓冲区必须提供地址");
        // 测试只通过公开 ABI 地址模拟 JavaScript 写入，长度已由 handle 固定。
        unsafe {
            std::ptr::copy_nonoverlapping(bytes.as_ptr(), pointer as *mut u8, bytes.len());
        }
        handle
    }

    fn read_and_close_buffer(handle: u32) -> Vec<u8> {
        let pointer = kelivo_opaque_server_buffer_pointer(handle);
        let length = kelivo_opaque_server_buffer_length(handle);
        assert_ne!(pointer, 0, "测试输出缓冲区必须提供地址");
        assert_ne!(length, 0, "测试输出缓冲区必须提供长度");
        // 输出在 close 前由 Rust handle 独占，复制后立即关闭以验证调用方责任。
        let bytes = unsafe { std::slice::from_raw_parts(pointer as *const u8, length) }.to_vec();
        assert_eq!(
            kelivo_opaque_server_buffer_close(handle),
            STATUS_OK,
            "测试输出缓冲区必须成功关闭"
        );
        bytes
    }

    fn uuid_v4(fill: u8) -> [u8; ACCOUNT_ID_LENGTH] {
        let mut uuid = [fill; ACCOUNT_ID_LENGTH];
        uuid[6] = (uuid[6] & 0x0f) | 0x40;
        uuid[8] = (uuid[8] & 0x3f) | 0x80;
        uuid
    }

    fn build_continuation_aad(
        attempt_id: &[u8; ACCOUNT_ID_LENGTH],
        account_id: &[u8; ACCOUNT_ID_LENGTH],
        expires_at_ms: u64,
    ) -> [u8; 48] {
        let mut aad = [0_u8; 48];
        aad[..4].copy_from_slice(b"KOAD");
        aad[4..6].copy_from_slice(&1_u16.to_be_bytes());
        aad[6..8].copy_from_slice(&0_u16.to_be_bytes());
        aad[8..24].copy_from_slice(attempt_id);
        aad[24..40].copy_from_slice(account_id);
        aad[40..48].copy_from_slice(&expires_at_ms.to_be_bytes());
        aad
    }

    fn registration_fixture(
        account_id: &[u8; ACCOUNT_ID_LENGTH],
        password: &[u8],
    ) -> (Vec<u8>, Vec<u8>) {
        let mut setup_rng = ChaCha20Rng::from_seed([0x41; RANDOM_SEED_LENGTH]);
        let setup = generate_server_setup(&mut setup_rng).expect("服务端配置应生成成功");
        let mut client_start_rng = ChaCha20Rng::from_seed([0x42; RANDOM_SEED_LENGTH]);
        let (client_state, request) = client_registration_start(&mut client_start_rng, password)
            .expect("客户端注册起始应成功")
            .into_parts();
        let response = kelivo_secure_core_protocol::server_registration_start(
            &setup,
            request,
            AccountBinding::new(account_id).expect("固定账户标识应有效"),
        )
        .expect("服务端注册起始应成功");
        let mut client_finish_rng = ChaCha20Rng::from_seed([0x43; RANDOM_SEED_LENGTH]);
        let upload = client_registration_finish(
            &mut client_finish_rng,
            client_state,
            password,
            response,
            AccountBinding::new(account_id).expect("固定账户标识应有效"),
        )
        .expect("客户端注册完成应成功")
        .into_upload();
        let record = kelivo_secure_core_protocol::server_registration_finish(upload)
            .expect("服务端注册完成应成功");
        (setup.as_bytes().to_vec(), record.as_bytes().to_vec())
    }

    fn call_login_start_for_aad(
        setup: &[u8],
        record: &[u8],
        account_id: &[u8; ACCOUNT_ID_LENGTH],
        aad: &[u8; 48],
        password: &[u8],
        seed_byte: u8,
    ) -> (i32, [u32; 7]) {
        let mut client_rng = ChaCha20Rng::from_seed([seed_byte; RANDOM_SEED_LENGTH]);
        let (_, request) = client_login_start(&mut client_rng, password)
            .expect("客户端登录起始应成功")
            .into_parts();
        let handles = [
            open_buffer(&[seed_byte.wrapping_add(1); RANDOM_SEED_LENGTH]),
            open_buffer(setup),
            open_buffer(record),
            open_buffer(request.as_bytes()),
            open_buffer(account_id),
            open_buffer(&[seed_byte.wrapping_add(2); SERVER_LOGIN_CONTINUATION_KEY_LENGTH]),
            open_buffer(aad),
        ];
        let status = kelivo_opaque_server_login_start(
            handles[0], handles[1], handles[2], handles[3], handles[4], handles[5], handles[6],
        );
        (status, handles)
    }

    #[test]
    fn fixed_buffer_handle_exposes_memory_until_closed() {
        let _guard = test_guard();
        let handle = kelivo_opaque_server_buffer_open(32);
        assert!(handle > 0, "固定长度缓冲区应成功分配");
        assert_ne!(
            kelivo_opaque_server_buffer_pointer(handle as u32),
            0,
            "有效句柄必须暴露线性内存地址"
        );
        assert_eq!(
            kelivo_opaque_server_buffer_length(handle as u32),
            32,
            "缓冲区长度必须保持固定"
        );
        assert_eq!(
            kelivo_opaque_server_buffer_close(handle as u32),
            0,
            "首次关闭必须成功"
        );
        assert_eq!(
            kelivo_opaque_server_buffer_pointer(handle as u32),
            0,
            "关闭后句柄必须立即失效"
        );
        assert_ne!(
            kelivo_opaque_server_buffer_close(handle as u32),
            0,
            "重复关闭不得伪装成功"
        );
    }

    #[test]
    fn registration_operations_exchange_fixed_protocol_messages() {
        let _guard = test_guard();
        let account_id = uuid_v4(0x21);
        let binding = AccountBinding::new(&account_id).expect("固定账户标识应有效");
        let password = b"server-wasm-registration-password";
        let mut setup_rng = ChaCha20Rng::from_seed([0x11; RANDOM_SEED_LENGTH]);
        let setup = generate_server_setup(&mut setup_rng).expect("服务端配置应生成成功");

        let mut registration_start_rng = ChaCha20Rng::from_seed([0x12; RANDOM_SEED_LENGTH]);
        let client_start = client_registration_start(&mut registration_start_rng, password)
            .expect("客户端注册起始应成功");
        let (client_state, request) = client_start.into_parts();

        let response_handle = kelivo_opaque_server_registration_start(
            open_buffer(setup.as_bytes()),
            open_buffer(request.as_bytes()),
            open_buffer(&account_id),
        );
        assert!(response_handle > 0, "服务端注册起始应返回输出句柄");
        let response_bytes = read_and_close_buffer(response_handle as u32);
        assert_eq!(response_bytes.len(), 80, "注册响应必须保持固定长度");
        let response =
            RegistrationResponse::from_bytes(&response_bytes).expect("注册响应线格式应有效");

        let mut registration_finish_rng = ChaCha20Rng::from_seed([0x13; RANDOM_SEED_LENGTH]);
        let upload = client_registration_finish(
            &mut registration_finish_rng,
            client_state,
            password,
            response,
            binding,
        )
        .expect("客户端注册完成应成功")
        .into_upload();

        let record_handle =
            kelivo_opaque_server_registration_finish(open_buffer(upload.as_bytes()));
        assert!(record_handle > 0, "服务端注册完成应返回记录句柄");
        let record_bytes = read_and_close_buffer(record_handle as u32);
        assert_eq!(record_bytes.len(), 208, "注册记录必须保持固定长度");
        RegistrationRecord::from_bytes(&record_bytes).expect("注册记录线格式应有效");
    }

    #[test]
    fn login_operations_authenticate_without_exporting_a_session_key() {
        let _guard = test_guard();
        let account_id = uuid_v4(0x51);
        let password = b"server-wasm-login-password";
        let (setup, record) = registration_fixture(&account_id, password);
        let mut client_start_rng = ChaCha20Rng::from_seed([0x52; RANDOM_SEED_LENGTH]);
        let (client_state, request) = client_login_start(&mut client_start_rng, password)
            .expect("客户端登录起始应成功")
            .into_parts();
        let continuation_key = [0x53_u8; 32];
        let continuation_aad =
            build_continuation_aad(&uuid_v4(0x54), &account_id, 1_800_000_000_000);

        let output_handle = kelivo_opaque_server_login_start(
            open_buffer(&[0x55; RANDOM_SEED_LENGTH]),
            open_buffer(&setup),
            open_buffer(&record),
            open_buffer(request.as_bytes()),
            open_buffer(&account_id),
            open_buffer(&continuation_key),
            open_buffer(&continuation_aad),
        );
        assert!(output_handle > 0, "服务端登录起始应返回固定输出句柄");
        let output = read_and_close_buffer(output_handle as u32);
        assert_eq!(
            output.len(),
            SERVER_LOGIN_OUTPUT_LENGTH,
            "登录响应和密封 continuation 必须组成固定输出"
        );
        let (response_bytes, continuation_bytes) = output.split_at(336);
        let response =
            CredentialResponse::from_bytes(response_bytes).expect("登录响应线格式应有效");

        let mut client_finish_rng = ChaCha20Rng::from_seed([0x56; RANDOM_SEED_LENGTH]);
        let finalization = client_login_finish(
            &mut client_finish_rng,
            client_state,
            password,
            response,
            AccountBinding::new(&account_id).expect("固定账户标识应有效"),
        )
        .expect("客户端登录完成应成功")
        .into_finalization();

        assert_eq!(
            kelivo_opaque_server_login_finish(
                open_buffer(continuation_bytes),
                open_buffer(&continuation_key),
                open_buffer(&continuation_aad),
                open_buffer(finalization.as_bytes()),
                open_buffer(&account_id),
            ),
            STATUS_OK,
            "服务端登录完成只能返回认证成功，不得返回会话密钥"
        );
    }

    #[test]
    fn login_start_validates_the_fixed_continuation_aad_contract() {
        let _guard = test_guard();
        let account_id = uuid_v4(0x91);
        let attempt_id = uuid_v4(0x92);
        let password = b"server-wasm-aad-validation-password";
        let (setup, record) = registration_fixture(&account_id, password);
        let valid_aad = build_continuation_aad(&attempt_id, &account_id, 1);

        let mut wrong_magic = valid_aad;
        wrong_magic[0] ^= 1;
        let mut wrong_version = valid_aad;
        wrong_version[5] = 2;
        let mut nonzero_flags = valid_aad;
        nonzero_flags[7] = 1;
        let mut malformed_attempt_id = valid_aad;
        malformed_attempt_id[14] = (malformed_attempt_id[14] & 0x0f) | 0x50;
        let mismatched_account =
            build_continuation_aad(&attempt_id, &uuid_v4(0x93), 1_800_000_000_003);
        let zero_expiry = build_continuation_aad(&attempt_id, &account_id, 0);
        let malformed_account_id = [0x94; ACCOUNT_ID_LENGTH];
        let malformed_account_aad =
            build_continuation_aad(&attempt_id, &malformed_account_id, 1_800_000_000_004);

        let invalid_cases = [
            ("magic", account_id, wrong_magic),
            ("version", account_id, wrong_version),
            ("flags", account_id, nonzero_flags),
            ("attempt UUID", account_id, malformed_attempt_id),
            ("account mismatch", account_id, mismatched_account),
            ("zero expiry", account_id, zero_expiry),
            ("account UUID", malformed_account_id, malformed_account_aad),
        ];
        for (index, (case_name, input_account_id, aad)) in invalid_cases.into_iter().enumerate() {
            let (status, handles) = call_login_start_for_aad(
                &setup,
                &record,
                &input_account_id,
                &aad,
                password,
                0xa0_u8.wrapping_add(index as u8),
            );
            assert_eq!(
                status, STATUS_INVALID_CONTINUATION_AAD,
                "{case_name} 必须被固定 AAD 校验拒绝"
            );
            for handle in handles {
                assert_eq!(
                    kelivo_opaque_server_buffer_length(handle),
                    0,
                    "{case_name} 失败后仍必须消费全部输入"
                );
            }
        }

        let (output_handle, handles) =
            call_login_start_for_aad(&setup, &record, &account_id, &valid_aad, password, 0xb0);
        assert!(output_handle > 0, "expiresAtMs=1 是最小有效边界");
        assert_eq!(
            read_and_close_buffer(output_handle as u32).len(),
            SERVER_LOGIN_OUTPUT_LENGTH,
            "有效边界仍必须返回固定登录输出"
        );
        for handle in handles {
            assert_eq!(
                kelivo_opaque_server_buffer_length(handle),
                0,
                "有效调用也必须消费全部输入"
            );
        }
    }

    #[test]
    fn login_finish_collapses_all_credential_failures() {
        let _guard = test_guard();
        let account_id = uuid_v4(0x61);
        let password = b"server-wasm-unified-failure-password";
        let (setup, record) = registration_fixture(&account_id, password);
        let mut client_start_rng = ChaCha20Rng::from_seed([0x62; RANDOM_SEED_LENGTH]);
        let (client_state, request) = client_login_start(&mut client_start_rng, password)
            .expect("客户端登录起始应成功")
            .into_parts();
        let continuation_key = [0x63_u8; SERVER_LOGIN_CONTINUATION_KEY_LENGTH];
        let continuation_aad =
            build_continuation_aad(&uuid_v4(0x64), &account_id, 1_800_000_000_001);
        let output_handle = kelivo_opaque_server_login_start(
            open_buffer(&[0x65; RANDOM_SEED_LENGTH]),
            open_buffer(&setup),
            open_buffer(&record),
            open_buffer(request.as_bytes()),
            open_buffer(&account_id),
            open_buffer(&continuation_key),
            open_buffer(&continuation_aad),
        );
        assert!(output_handle > 0, "服务端登录起始应返回固定输出句柄");
        let output = read_and_close_buffer(output_handle as u32);
        let (response_bytes, continuation_bytes) = output.split_at(CREDENTIAL_RESPONSE_LENGTH);
        let response =
            CredentialResponse::from_bytes(response_bytes).expect("登录响应线格式应有效");
        let mut client_finish_rng = ChaCha20Rng::from_seed([0x66; RANDOM_SEED_LENGTH]);
        let finalization = client_login_finish(
            &mut client_finish_rng,
            client_state,
            password,
            response,
            AccountBinding::new(&account_id).expect("固定账户标识应有效"),
        )
        .expect("客户端登录完成应成功")
        .into_finalization();

        let mut corrupted_continuation = continuation_bytes.to_vec();
        let last_continuation_byte = corrupted_continuation
            .last_mut()
            .expect("固定 continuation 不得为空");
        *last_continuation_byte ^= 1;
        let wrong_aad = build_continuation_aad(&uuid_v4(0x67), &account_id, 1_800_000_000_001);
        let mismatched_account_aad =
            build_continuation_aad(&uuid_v4(0x64), &uuid_v4(0x68), 1_800_000_000_001);
        let mut corrupted_finalization = finalization.as_bytes().to_vec();
        let last_finalization_byte = corrupted_finalization
            .last_mut()
            .expect("固定 finalization 不得为空");
        *last_finalization_byte ^= 1;

        let statuses = [
            kelivo_opaque_server_login_finish(
                open_buffer(&corrupted_continuation),
                open_buffer(&continuation_key),
                open_buffer(&continuation_aad),
                open_buffer(finalization.as_bytes()),
                open_buffer(&account_id),
            ),
            kelivo_opaque_server_login_finish(
                open_buffer(continuation_bytes),
                open_buffer(&continuation_key),
                open_buffer(&wrong_aad),
                open_buffer(finalization.as_bytes()),
                open_buffer(&account_id),
            ),
            kelivo_opaque_server_login_finish(
                open_buffer(continuation_bytes),
                open_buffer(&continuation_key),
                open_buffer(&mismatched_account_aad),
                open_buffer(finalization.as_bytes()),
                open_buffer(&account_id),
            ),
            kelivo_opaque_server_login_finish(
                open_buffer(continuation_bytes),
                open_buffer(&continuation_key),
                open_buffer(&continuation_aad),
                open_buffer(&corrupted_finalization),
                open_buffer(&account_id),
            ),
        ];
        assert_eq!(
            statuses, [STATUS_AUTHENTICATION_FAILED; 4],
            "密封状态、AAD 与客户端证明失败不得形成可区分 oracle"
        );
    }

    #[test]
    fn fixed_buffer_registry_enforces_bounds_without_reusing_handles() {
        let _guard = test_guard();
        assert_eq!(
            kelivo_opaque_server_buffer_open(17),
            STATUS_UNSUPPORTED_BUFFER_LENGTH,
            "ABI 不接受未约定长度"
        );

        let mut handles = Vec::with_capacity(MAX_ACTIVE_BUFFERS);
        for _ in 0..MAX_ACTIVE_BUFFERS {
            let handle = kelivo_opaque_server_buffer_open(ACCOUNT_ID_LENGTH);
            assert!(handle > 0, "上限内缓冲区应成功分配");
            handles.push(handle as u32);
        }
        assert_eq!(
            kelivo_opaque_server_buffer_open(ACCOUNT_ID_LENGTH),
            STATUS_TOO_MANY_ACTIVE_BUFFERS,
            "第六十五个并发缓冲区必须被拒绝"
        );
        let previous = handles[0];
        for handle in handles {
            assert_eq!(
                kelivo_opaque_server_buffer_close(handle),
                STATUS_OK,
                "上限测试句柄必须成功清理"
            );
        }
        let replacement = kelivo_opaque_server_buffer_open(ACCOUNT_ID_LENGTH);
        assert!(replacement > 0, "释放容量后应允许新缓冲区");
        assert_ne!(
            replacement as u32, previous,
            "已关闭句柄不得复用，避免陈旧引用重新生效"
        );
        assert_eq!(
            kelivo_opaque_server_buffer_close(replacement as u32),
            STATUS_OK,
            "替代缓冲区必须成功清理"
        );
    }

    #[test]
    fn duplicated_input_handle_invalidates_the_entire_call() {
        let _guard = test_guard();
        let account_id = uuid_v4(0xc1);
        let random_seed_handle = open_buffer(&[0xc2; RANDOM_SEED_LENGTH]);
        let setup_handle = open_buffer(&[0xc3; SERVER_SETUP_LENGTH]);
        let request_handle = open_buffer(&[0xc4; CREDENTIAL_REQUEST_LENGTH]);
        let account_handle = open_buffer(&account_id);
        let aad_handle = open_buffer(&build_continuation_aad(&uuid_v4(0xc5), &account_id, 1));

        assert_eq!(
            kelivo_opaque_server_login_start(
                random_seed_handle,
                setup_handle,
                INVALID_BUFFER_HANDLE as u32,
                request_handle,
                account_handle,
                random_seed_handle,
                aad_handle,
            ),
            STATUS_INVALID_BUFFER_HANDLE,
            "同一输入句柄不得同时充当随机种子与 continuation 密钥"
        );
        for handle in [
            random_seed_handle,
            setup_handle,
            request_handle,
            account_handle,
            aad_handle,
        ] {
            assert_eq!(
                kelivo_opaque_server_buffer_length(handle),
                0,
                "重复引用失败后全部输入都必须被销毁"
            );
        }
    }

    #[test]
    fn protocol_rng_has_compile_time_zeroize_on_drop_contract() {
        let _guard = test_guard();
        fn require_zeroize_on_drop<T: ZeroizeOnDrop>() {}

        require_zeroize_on_drop::<ZeroizingChaCha20Rng>();
        require_zeroize_on_drop::<ProtocolRng>();
    }

    #[test]
    fn unknown_account_login_start_keeps_the_same_fixed_shape() {
        let _guard = test_guard();
        let account_id = uuid_v4(0x71);
        let password = b"server-wasm-unknown-account-password";
        let mut setup_rng = ChaCha20Rng::from_seed([0x72; RANDOM_SEED_LENGTH]);
        let setup = generate_server_setup(&mut setup_rng).expect("服务端配置应生成成功");
        let mut client_rng = ChaCha20Rng::from_seed([0x73; RANDOM_SEED_LENGTH]);
        let (_, request) = client_login_start(&mut client_rng, password)
            .expect("客户端登录起始应成功")
            .into_parts();
        let random_seed_handle = open_buffer(&[0x74; RANDOM_SEED_LENGTH]);
        let setup_handle = open_buffer(setup.as_bytes());
        let request_handle = open_buffer(request.as_bytes());
        let account_handle = open_buffer(&account_id);
        let continuation_key_handle = open_buffer(&[0x75; SERVER_LOGIN_CONTINUATION_KEY_LENGTH]);
        let continuation_aad_handle = open_buffer(&build_continuation_aad(
            &uuid_v4(0x76),
            &account_id,
            1_800_000_000_002,
        ));

        let output_handle = kelivo_opaque_server_login_start(
            random_seed_handle,
            setup_handle,
            INVALID_BUFFER_HANDLE as u32,
            request_handle,
            account_handle,
            continuation_key_handle,
            continuation_aad_handle,
        );
        assert!(output_handle > 0, "未知账户仍必须返回固定登录输出");
        let output = read_and_close_buffer(output_handle as u32);
        assert_eq!(
            output.len(),
            SERVER_LOGIN_OUTPUT_LENGTH,
            "未知账户不得通过输出长度泄露存在性"
        );
        for consumed_handle in [
            random_seed_handle,
            setup_handle,
            request_handle,
            account_handle,
            continuation_key_handle,
            continuation_aad_handle,
        ] {
            assert_eq!(
                kelivo_opaque_server_buffer_length(consumed_handle),
                0,
                "登录起始必须单次消费并清理全部输入 handle"
            );
        }
    }

    #[test]
    fn protocol_error_consumes_every_registration_input() {
        let _guard = test_guard();
        let account_id = uuid_v4(0x81);
        let mut setup_rng = ChaCha20Rng::from_seed([0x82; RANDOM_SEED_LENGTH]);
        let setup = generate_server_setup(&mut setup_rng).expect("服务端配置应生成成功");
        let setup_handle = open_buffer(setup.as_bytes());
        let malformed_request_handle = open_buffer(&[0_u8; REGISTRATION_REQUEST_LENGTH]);
        let account_handle = open_buffer(&account_id);

        assert_eq!(
            kelivo_opaque_server_registration_start(
                setup_handle,
                malformed_request_handle,
                account_handle,
            ),
            STATUS_PROTOCOL_FAILED,
            "无效协议消息必须明确失败"
        );
        for consumed_handle in [setup_handle, malformed_request_handle, account_handle] {
            assert_eq!(
                kelivo_opaque_server_buffer_length(consumed_handle),
                0,
                "失败路径也必须单次消费并清理全部输入 handle"
            );
        }
    }
}
