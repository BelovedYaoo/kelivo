#![forbid(unsafe_code)]

//! Kelivo 端到端加密认证使用的纯 Rust OPAQUE 协议核心。

use std::fmt;
use std::ops::Deref;

use chacha20poly1305::{
    Tag, XChaCha20Poly1305, XNonce,
    aead::{AeadInOut, KeyInit},
};
use opaque_ke::errors::ProtocolError as OpaqueProtocolError;
use opaque_ke::{
    CipherSuite, ClientLogin as OpaqueClientLogin,
    ClientLoginFinishParameters as OpaqueClientLoginFinishParameters,
    ClientRegistration as OpaqueClientRegistration,
    ClientRegistrationFinishParameters as OpaqueClientRegistrationFinishParameters,
    CredentialFinalization as OpaqueCredentialFinalization,
    CredentialRequest as OpaqueCredentialRequest, CredentialResponse as OpaqueCredentialResponse,
    Identifiers, RegistrationRequest as OpaqueRegistrationRequest,
    RegistrationResponse as OpaqueRegistrationResponse,
    RegistrationUpload as OpaqueRegistrationUpload, Ristretto255, ServerLogin as OpaqueServerLogin,
    ServerLoginParameters as OpaqueServerLoginParameters,
    ServerRegistration as OpaqueServerRegistration, ServerSetup as OpaqueServerSetup, TripleDh,
};
use rand::rngs::OsRng;
use rand::{CryptoRng, RngCore};
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

const WIRE_MAGIC: [u8; 4] = *b"KOPA";
const WIRE_HEADER_LENGTH: usize = 16;
const WIRE_FLAGS: u8 = 0;
const SERVER_LOGIN_STATE_LENGTH: usize = 128;
const SERVER_LOGIN_CONTINUATION_MAGIC: [u8; 4] = *b"KOSC";
const SERVER_LOGIN_CONTINUATION_HEADER_LENGTH: usize = 8;
const SERVER_LOGIN_CONTINUATION_NONCE_LENGTH: usize = 24;
const SERVER_LOGIN_CONTINUATION_TAG_LENGTH: usize = 16;
const SERVER_LOGIN_CONTINUATION_CIPHERTEXT_OFFSET: usize =
    SERVER_LOGIN_CONTINUATION_HEADER_LENGTH + SERVER_LOGIN_CONTINUATION_NONCE_LENGTH;
const SERVER_LOGIN_CONTINUATION_TAG_OFFSET: usize =
    SERVER_LOGIN_CONTINUATION_CIPHERTEXT_OFFSET + SERVER_LOGIN_STATE_LENGTH;
const SERVER_LOGIN_CONTINUATION_AAD_DOMAIN: &[u8] = b"kelivo.opaque.server-login-state.v1";
pub const MAX_OPAQUE_INPUT_LENGTH: usize = u16::MAX as usize;
const OPAQUE_CONTEXT: &[u8] = b"Kelivo-OPAQUE-v1";
const SERVER_IDENTIFIER: &[u8] = b"kelivo-cloud-v1";

pub const FORMAT_VERSION: u16 = 1;
pub const CIPHERSUITE_ID: u16 = 1;
pub const PASSWORD_PROFILE_ID: u16 = 1;
pub const ARGON2_MEMORY_KIB: u32 = 65_536;
pub const ARGON2_ITERATIONS: u32 = 3;
pub const ARGON2_PARALLELISM: u32 = 4;
pub const KEY_LENGTH: usize = 64;
pub const SERVER_SETUP_LENGTH: usize = WIRE_HEADER_LENGTH + 128;
pub const REGISTRATION_REQUEST_LENGTH: usize = WIRE_HEADER_LENGTH + 32;
pub const REGISTRATION_RESPONSE_LENGTH: usize = WIRE_HEADER_LENGTH + 64;
pub const REGISTRATION_UPLOAD_LENGTH: usize = WIRE_HEADER_LENGTH + 192;
pub const REGISTRATION_RECORD_LENGTH: usize = WIRE_HEADER_LENGTH + 192;
pub const CREDENTIAL_REQUEST_LENGTH: usize = WIRE_HEADER_LENGTH + 96;
pub const CREDENTIAL_RESPONSE_LENGTH: usize = WIRE_HEADER_LENGTH + 320;
pub const CREDENTIAL_FINALIZATION_LENGTH: usize = WIRE_HEADER_LENGTH + 64;
pub const SERVER_LOGIN_CONTINUATION_FORMAT_VERSION: u16 = 1;
pub const SERVER_LOGIN_CONTINUATION_CIPHER_SUITE_ID: u16 = 1;
pub const SERVER_LOGIN_CONTINUATION_KEY_LENGTH: usize = 32;
pub const SERVER_LOGIN_CONTINUATION_LENGTH: usize =
    SERVER_LOGIN_CONTINUATION_TAG_OFFSET + SERVER_LOGIN_CONTINUATION_TAG_LENGTH;
/// AAD 只承载账户、设备与登录尝试等有界绑定信息，不允许塞入业务正文。
/// 恰好 64 KiB 可以使用；再多一个字节会在读取随机源或执行 OPAQUE 前被拒绝。
pub const MAX_SERVER_LOGIN_CONTINUATION_AAD_LENGTH: usize = 64 * 1024;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ProtocolProfile {
    pub format_version: u16,
    pub ciphersuite_id: u16,
    pub password_profile_id: u16,
    pub argon2_memory_kib: u32,
    pub argon2_iterations: u32,
    pub argon2_parallelism: u32,
}

pub const PROTOCOL_PROFILE: ProtocolProfile = ProtocolProfile {
    format_version: FORMAT_VERSION,
    ciphersuite_id: CIPHERSUITE_ID,
    password_profile_id: PASSWORD_PROFILE_ID,
    argon2_memory_kib: ARGON2_MEMORY_KIB,
    argon2_iterations: ARGON2_ITERATIONS,
    argon2_parallelism: ARGON2_PARALLELISM,
};

struct Rfc9807Suite;

impl CipherSuite for Rfc9807Suite {
    type OprfCs = Ristretto255;
    type KeyExchange = TripleDh<Ristretto255, sha2_opaque::Sha512>;
    type Ksf = opaque_ke::argon2::Argon2<'static>;
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Error {
    InvalidMagic,
    UnsupportedFormatVersion(u16),
    UnsupportedCipherSuite(u16),
    UnsupportedPasswordProfile(u16),
    UnsupportedFlags(u8),
    UnexpectedObjectKind { expected: u8, actual: u8 },
    InvalidPayloadLength { expected: usize, actual: usize },
    InvalidWireLength { expected: usize, actual: usize },
    InvalidCredentialIdentifierLength,
    InvalidPasswordLength,
    InvalidPasswordProfileConfiguration,
    RandomnessUnavailable,
    InvalidServerLoginContinuationKeyLength { expected: usize, actual: usize },
    InvalidServerLoginContinuationMagic,
    UnsupportedServerLoginContinuationVersion(u16),
    UnsupportedServerLoginContinuationCipherSuite(u16),
    InvalidServerLoginContinuationLength { expected: usize, actual: usize },
    ServerLoginContinuationAadTooLarge,
    ServerLoginContinuationCrypto,
    ServerLoginContinuationAuthenticationFailed,
    Opaque(OpaqueProtocolError),
}

impl fmt::Display for Error {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidMagic => formatter.write_str("OPAQUE 数据魔数无效"),
            Self::UnsupportedFormatVersion(version) => {
                write!(formatter, "不支持的 OPAQUE 格式版本：{version}")
            }
            Self::UnsupportedCipherSuite(ciphersuite) => {
                write!(formatter, "不支持的 OPAQUE 密码套件：{ciphersuite}")
            }
            Self::UnsupportedPasswordProfile(profile) => {
                write!(formatter, "不支持的 OPAQUE 密码配置：{profile}")
            }
            Self::UnsupportedFlags(flags) => {
                write!(formatter, "OPAQUE 数据包含不支持的标志：{flags}")
            }
            Self::UnexpectedObjectKind { expected, actual } => write!(
                formatter,
                "OPAQUE 对象类型不匹配，预期 {expected}，实际 {actual}"
            ),
            Self::InvalidPayloadLength { expected, actual } => write!(
                formatter,
                "OPAQUE payload 长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::InvalidWireLength { expected, actual } => write!(
                formatter,
                "OPAQUE 数据总长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::InvalidCredentialIdentifierLength => {
                formatter.write_str("OPAQUE 凭据标识长度无效")
            }
            Self::InvalidPasswordLength => formatter.write_str("OPAQUE 密码长度无效"),
            Self::InvalidPasswordProfileConfiguration => {
                formatter.write_str("OPAQUE 密码配置参数无效")
            }
            Self::RandomnessUnavailable => formatter.write_str("系统安全随机源不可用"),
            Self::InvalidServerLoginContinuationKeyLength { expected, actual } => write!(
                formatter,
                "OPAQUE 服务端登录状态密钥长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::InvalidServerLoginContinuationMagic => {
                formatter.write_str("OPAQUE 服务端登录状态魔数无效")
            }
            Self::UnsupportedServerLoginContinuationVersion(version) => {
                write!(formatter, "不支持的 OPAQUE 服务端登录状态版本：{version}")
            }
            Self::UnsupportedServerLoginContinuationCipherSuite(cipher_suite) => write!(
                formatter,
                "不支持的 OPAQUE 服务端登录状态密码套件：{cipher_suite}"
            ),
            Self::InvalidServerLoginContinuationLength { expected, actual } => write!(
                formatter,
                "OPAQUE 服务端登录状态长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::ServerLoginContinuationAadTooLarge => {
                formatter.write_str("OPAQUE 服务端登录状态关联数据过大")
            }
            Self::ServerLoginContinuationCrypto => {
                formatter.write_str("OPAQUE 服务端登录状态密封失败")
            }
            Self::ServerLoginContinuationAuthenticationFailed => {
                formatter.write_str("OPAQUE 服务端登录状态认证失败")
            }
            Self::Opaque(error) => write!(formatter, "OPAQUE 协议失败：{error:?}"),
        }
    }
}

impl std::error::Error for Error {}

impl From<OpaqueProtocolError> for Error {
    fn from(error: OpaqueProtocolError) -> Self {
        Self::Opaque(error)
    }
}

#[derive(Clone, Copy)]
pub struct AccountBinding<'a> {
    credential_identifier: &'a [u8],
}

impl<'a> AccountBinding<'a> {
    pub fn new(credential_identifier: &'a [u8]) -> Result<Self, Error> {
        if credential_identifier.is_empty() || credential_identifier.len() > MAX_OPAQUE_INPUT_LENGTH
        {
            return Err(Error::InvalidCredentialIdentifierLength);
        }
        Ok(Self {
            credential_identifier,
        })
    }

    pub fn credential_identifier(&self) -> &'a [u8] {
        self.credential_identifier
    }

    fn identifiers(&self) -> Identifiers<'a> {
        Identifiers {
            client: Some(self.credential_identifier),
            // 使用逻辑服务身份，避免域名调整导致既有凭据永久失效。
            server: Some(SERVER_IDENTIFIER),
        }
    }
}

#[derive(Clone, Copy)]
enum ObjectKind {
    ServerSetup = 1,
    #[cfg(test)]
    ClientRegistrationState = 2,
    RegistrationRequest = 3,
    RegistrationResponse = 4,
    RegistrationUpload = 5,
    RegistrationRecord = 6,
    #[cfg(test)]
    ClientLoginState = 7,
    CredentialRequest = 8,
    #[cfg(test)]
    ServerLoginState = 9,
    CredentialResponse = 10,
    CredentialFinalization = 11,
}

impl ObjectKind {
    const fn id(self) -> u8 {
        self as u8
    }

    const fn payload_length(self) -> usize {
        match self {
            Self::ServerSetup => 128,
            #[cfg(test)]
            Self::ClientRegistrationState => 64,
            Self::RegistrationRequest => 32,
            Self::RegistrationResponse => 64,
            Self::RegistrationUpload | Self::RegistrationRecord => 192,
            #[cfg(test)]
            Self::ClientLoginState => 192,
            Self::CredentialRequest => 96,
            #[cfg(test)]
            Self::ServerLoginState => SERVER_LOGIN_STATE_LENGTH,
            Self::CredentialResponse => 320,
            Self::CredentialFinalization => 64,
        }
    }
}

const _: () = {
    assert!(SERVER_SETUP_LENGTH == WIRE_HEADER_LENGTH + ObjectKind::ServerSetup.payload_length());
    assert!(
        REGISTRATION_REQUEST_LENGTH
            == WIRE_HEADER_LENGTH + ObjectKind::RegistrationRequest.payload_length()
    );
    assert!(
        REGISTRATION_RESPONSE_LENGTH
            == WIRE_HEADER_LENGTH + ObjectKind::RegistrationResponse.payload_length()
    );
    assert!(
        REGISTRATION_UPLOAD_LENGTH
            == WIRE_HEADER_LENGTH + ObjectKind::RegistrationUpload.payload_length()
    );
    assert!(
        REGISTRATION_RECORD_LENGTH
            == WIRE_HEADER_LENGTH + ObjectKind::RegistrationRecord.payload_length()
    );
    assert!(
        CREDENTIAL_REQUEST_LENGTH
            == WIRE_HEADER_LENGTH + ObjectKind::CredentialRequest.payload_length()
    );
    assert!(
        CREDENTIAL_RESPONSE_LENGTH
            == WIRE_HEADER_LENGTH + ObjectKind::CredentialResponse.payload_length()
    );
    assert!(
        CREDENTIAL_FINALIZATION_LENGTH
            == WIRE_HEADER_LENGTH + ObjectKind::CredentialFinalization.payload_length()
    );
};

struct EncodedObject {
    bytes: Zeroizing<Vec<u8>>,
}

impl EncodedObject {
    fn encode(kind: ObjectKind, payload: &[u8]) -> Result<Self, Error> {
        if payload.len() != kind.payload_length() {
            return Err(Error::InvalidPayloadLength {
                expected: kind.payload_length(),
                actual: payload.len(),
            });
        }

        let mut bytes = Zeroizing::new(Vec::with_capacity(WIRE_HEADER_LENGTH + payload.len()));
        bytes.extend_from_slice(&WIRE_MAGIC);
        bytes.extend_from_slice(&FORMAT_VERSION.to_be_bytes());
        bytes.extend_from_slice(&CIPHERSUITE_ID.to_be_bytes());
        bytes.extend_from_slice(&PASSWORD_PROFILE_ID.to_be_bytes());
        bytes.push(kind.id());
        bytes.push(WIRE_FLAGS);
        bytes.extend_from_slice(&(payload.len() as u32).to_be_bytes());
        bytes.extend_from_slice(payload);
        Ok(Self { bytes })
    }

    fn parse(kind: ObjectKind, bytes: &[u8]) -> Result<Self, Error> {
        if bytes.len() < WIRE_HEADER_LENGTH {
            return Err(Error::InvalidWireLength {
                expected: WIRE_HEADER_LENGTH,
                actual: bytes.len(),
            });
        }
        if bytes[..WIRE_MAGIC.len()] != WIRE_MAGIC {
            return Err(Error::InvalidMagic);
        }

        let format_version = u16::from_be_bytes([bytes[4], bytes[5]]);
        if format_version != FORMAT_VERSION {
            return Err(Error::UnsupportedFormatVersion(format_version));
        }

        let ciphersuite_id = u16::from_be_bytes([bytes[6], bytes[7]]);
        if ciphersuite_id != CIPHERSUITE_ID {
            return Err(Error::UnsupportedCipherSuite(ciphersuite_id));
        }

        let password_profile_id = u16::from_be_bytes([bytes[8], bytes[9]]);
        if password_profile_id != PASSWORD_PROFILE_ID {
            return Err(Error::UnsupportedPasswordProfile(password_profile_id));
        }

        if bytes[10] != kind.id() {
            return Err(Error::UnexpectedObjectKind {
                expected: kind.id(),
                actual: bytes[10],
            });
        }
        if bytes[11] != WIRE_FLAGS {
            return Err(Error::UnsupportedFlags(bytes[11]));
        }

        let declared_payload_length =
            u32::from_be_bytes([bytes[12], bytes[13], bytes[14], bytes[15]]) as usize;
        if declared_payload_length != kind.payload_length() {
            return Err(Error::InvalidPayloadLength {
                expected: kind.payload_length(),
                actual: declared_payload_length,
            });
        }

        let expected_wire_length = WIRE_HEADER_LENGTH + declared_payload_length;
        if bytes.len() != expected_wire_length {
            return Err(Error::InvalidWireLength {
                expected: expected_wire_length,
                actual: bytes.len(),
            });
        }

        Ok(Self {
            bytes: Zeroizing::new(bytes.to_vec()),
        })
    }

    fn payload(&self) -> &[u8] {
        &self.bytes[WIRE_HEADER_LENGTH..]
    }

    fn as_bytes(&self) -> &[u8] {
        &self.bytes
    }
}

macro_rules! define_wire_object {
    ($name:ident, $kind:ident, $opaque:ty) => {
        pub struct $name(EncodedObject);

        impl $name {
            pub fn from_bytes(bytes: &[u8]) -> Result<Self, Error> {
                let encoded = EncodedObject::parse(ObjectKind::$kind, bytes)?;
                <$opaque>::deserialize(encoded.payload())?;
                Ok(Self(encoded))
            }

            pub fn as_bytes(&self) -> &[u8] {
                self.0.as_bytes()
            }

            fn from_value(value: &$opaque) -> Result<Self, Error> {
                let serialized = Zeroizing::new(value.serialize());
                Ok(Self(EncodedObject::encode(
                    ObjectKind::$kind,
                    serialized.as_slice(),
                )?))
            }

            fn decode(&self) -> Result<$opaque, Error> {
                Ok(<$opaque>::deserialize(self.0.payload())?)
            }
        }
    };
}

macro_rules! define_secret_state {
    ($name:ident, $kind:ident, $opaque:ty) => {
        // 直接持有 opaque-ke 的零化状态，避免生产构建获得可持久化秘密状态的字节入口。
        pub struct $name($opaque);

        impl $name {
            fn from_value(value: $opaque) -> Self {
                Self(value)
            }

            fn into_value(self) -> $opaque {
                self.0
            }

            // 私有测试线格式只用于锁定依赖升级影响，不能成为跨进程状态恢复机制。
            #[cfg(test)]
            fn from_wire_bytes_for_test(bytes: &[u8]) -> Result<Self, Error> {
                let encoded = EncodedObject::parse(ObjectKind::$kind, bytes)?;
                Ok(Self(<$opaque>::deserialize(encoded.payload())?))
            }

            #[cfg(test)]
            fn wire_bytes_for_test(&self) -> Result<Zeroizing<Vec<u8>>, Error> {
                let serialized = Zeroizing::new(self.0.serialize());
                let encoded = EncodedObject::encode(ObjectKind::$kind, serialized.as_slice())?;
                Ok(Zeroizing::new(encoded.as_bytes().to_vec()))
            }
        }
    };
}

define_wire_object!(ServerSetup, ServerSetup, OpaqueServerSetup<Rfc9807Suite>);
define_secret_state!(
    ClientRegistrationState,
    ClientRegistrationState,
    OpaqueClientRegistration<Rfc9807Suite>
);
define_wire_object!(
    RegistrationRequest,
    RegistrationRequest,
    OpaqueRegistrationRequest<Rfc9807Suite>
);
define_wire_object!(
    RegistrationResponse,
    RegistrationResponse,
    OpaqueRegistrationResponse<Rfc9807Suite>
);
define_wire_object!(
    RegistrationUpload,
    RegistrationUpload,
    OpaqueRegistrationUpload<Rfc9807Suite>
);
define_wire_object!(
    RegistrationRecord,
    RegistrationRecord,
    OpaqueServerRegistration<Rfc9807Suite>
);
define_secret_state!(
    ClientLoginState,
    ClientLoginState,
    OpaqueClientLogin<Rfc9807Suite>
);
define_wire_object!(
    CredentialRequest,
    CredentialRequest,
    OpaqueCredentialRequest<Rfc9807Suite>
);
define_secret_state!(
    ServerLoginState,
    ServerLoginState,
    OpaqueServerLogin<Rfc9807Suite>
);
define_wire_object!(
    CredentialResponse,
    CredentialResponse,
    OpaqueCredentialResponse<Rfc9807Suite>
);
define_wire_object!(
    CredentialFinalization,
    CredentialFinalization,
    OpaqueCredentialFinalization<Rfc9807Suite>
);

pub struct SessionKey(Zeroizing<Vec<u8>>);

impl SessionKey {
    pub fn as_bytes(&self) -> &[u8] {
        &self.0
    }

    fn from_material<T>(material: Zeroizing<T>) -> Self
    where
        T: AsRef<[u8]> + Zeroize,
    {
        Self(Zeroizing::new(
            AsRef::<[u8]>::as_ref(material.deref()).to_vec(),
        ))
    }
}

/// 服务端登录状态密封密钥。原始字节只允许在构造时进入协议模块。
///
/// 外部调用方不能解构密钥并读回原始字节：
///
/// ```compile_fail
/// use kelivo_secure_core_protocol::ServerLoginContinuationKey;
///
/// let key = ServerLoginContinuationKey::from_bytes(&[0x31; 32]).unwrap();
/// let ServerLoginContinuationKey(raw) = key;
/// let _ = raw;
/// ```
pub struct ServerLoginContinuationKey([u8; SERVER_LOGIN_CONTINUATION_KEY_LENGTH]);

impl ServerLoginContinuationKey {
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, Error> {
        let actual = bytes.len();
        let key: [u8; SERVER_LOGIN_CONTINUATION_KEY_LENGTH] =
            bytes
                .try_into()
                .map_err(|_| Error::InvalidServerLoginContinuationKeyLength {
                    expected: SERVER_LOGIN_CONTINUATION_KEY_LENGTH,
                    actual,
                })?;
        Ok(Self(key))
    }

    fn as_bytes(&self) -> &[u8; SERVER_LOGIN_CONTINUATION_KEY_LENGTH] {
        &self.0
    }
}

impl Zeroize for ServerLoginContinuationKey {
    fn zeroize(&mut self) {
        self.0.zeroize();
    }
}

impl ZeroizeOnDrop for ServerLoginContinuationKey {}

impl Drop for ServerLoginContinuationKey {
    fn drop(&mut self) {
        self.zeroize();
    }
}

pub struct ServerLoginContinuation([u8; SERVER_LOGIN_CONTINUATION_LENGTH]);

impl ServerLoginContinuation {
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, Error> {
        if bytes.len() != SERVER_LOGIN_CONTINUATION_LENGTH {
            return Err(Error::InvalidServerLoginContinuationLength {
                expected: SERVER_LOGIN_CONTINUATION_LENGTH,
                actual: bytes.len(),
            });
        }
        if bytes[..SERVER_LOGIN_CONTINUATION_MAGIC.len()] != SERVER_LOGIN_CONTINUATION_MAGIC {
            return Err(Error::InvalidServerLoginContinuationMagic);
        }
        let version = u16::from_be_bytes([bytes[4], bytes[5]]);
        if version != SERVER_LOGIN_CONTINUATION_FORMAT_VERSION {
            return Err(Error::UnsupportedServerLoginContinuationVersion(version));
        }
        let cipher_suite = u16::from_be_bytes([bytes[6], bytes[7]]);
        if cipher_suite != SERVER_LOGIN_CONTINUATION_CIPHER_SUITE_ID {
            return Err(Error::UnsupportedServerLoginContinuationCipherSuite(
                cipher_suite,
            ));
        }

        let mut continuation = [0_u8; SERVER_LOGIN_CONTINUATION_LENGTH];
        continuation.copy_from_slice(bytes);
        Ok(Self(continuation))
    }

    pub fn as_bytes(&self) -> &[u8] {
        &self.0
    }
}

pub struct ClientRegistrationStart {
    state: ClientRegistrationState,
    request: RegistrationRequest,
}

pub struct ClientRegistrationFinish {
    upload: RegistrationUpload,
}

pub struct ClientLoginStart {
    state: ClientLoginState,
    request: CredentialRequest,
}

pub struct ServerLoginStart {
    pub state: ServerLoginState,
    pub response: CredentialResponse,
}

/// 密封登录起始结果只允许通过 `into_parts` 取得公开响应与密封 continuation。
///
/// 外部调用方不能绕过接口读取结果内部字段：
///
/// ```compile_fail
/// use kelivo_secure_core_protocol::SealedServerLoginStart;
///
/// fn expose(result: SealedServerLoginStart) {
///     let SealedServerLoginStart {
///         response,
///         continuation,
///     } = result;
///     let _ = (response, continuation);
/// }
/// ```
pub struct SealedServerLoginStart {
    response: CredentialResponse,
    continuation: ServerLoginContinuation,
}

pub struct ClientLoginFinish {
    finalization: CredentialFinalization,
    session_key: SessionKey,
}

impl ClientRegistrationStart {
    pub fn into_parts(self) -> (ClientRegistrationState, RegistrationRequest) {
        (self.state, self.request)
    }
}

impl ClientRegistrationFinish {
    pub fn into_upload(self) -> RegistrationUpload {
        self.upload
    }
}

impl ClientLoginStart {
    pub fn into_parts(self) -> (ClientLoginState, CredentialRequest) {
        (self.state, self.request)
    }
}

impl SealedServerLoginStart {
    pub fn into_parts(self) -> (CredentialResponse, ServerLoginContinuation) {
        (self.response, self.continuation)
    }
}

impl ClientLoginFinish {
    pub fn into_finalization(self) -> CredentialFinalization {
        // 客户端原生接口只需要认证消息；会话密钥在返回前随 self 一并归零销毁。
        let Self {
            finalization,
            session_key,
        } = self;
        drop(session_key);
        finalization
    }
}

fn validate_password(password: &[u8]) -> Result<(), Error> {
    if password.is_empty() || password.len() > MAX_OPAQUE_INPUT_LENGTH {
        return Err(Error::InvalidPasswordLength);
    }
    Ok(())
}

fn password_ksf() -> Result<opaque_ke::argon2::Argon2<'static>, Error> {
    let parameters = opaque_ke::argon2::Params::new(
        ARGON2_MEMORY_KIB,
        ARGON2_ITERATIONS,
        ARGON2_PARALLELISM,
        Some(KEY_LENGTH),
    )
    .map_err(|_| Error::InvalidPasswordProfileConfiguration)?;
    Ok(opaque_ke::argon2::Argon2::new(
        opaque_ke::argon2::Algorithm::Argon2id,
        opaque_ke::argon2::Version::V0x13,
        parameters,
    ))
}

fn probe_random_source<R>(mut rng: R) -> Result<R, Error>
where
    R: RngCore,
{
    let mut probe = Zeroizing::new([0_u8; 32]);
    // 先验证运行时随机源，避免任何平台在初始化失败后退回确定性数据。
    rng.try_fill_bytes(probe.as_mut())
        .map_err(|_| Error::RandomnessUnavailable)?;
    Ok(rng)
}

pub fn system_rng() -> Result<OsRng, Error> {
    probe_random_source(OsRng)
}

pub fn generate_server_setup<R>(rng: &mut R) -> Result<ServerSetup, Error>
where
    R: CryptoRng + RngCore,
{
    ServerSetup::from_value(&OpaqueServerSetup::<Rfc9807Suite>::new(rng))
}

pub fn client_registration_start<R>(
    rng: &mut R,
    password: &[u8],
) -> Result<ClientRegistrationStart, Error>
where
    R: CryptoRng + RngCore,
{
    validate_password(password)?;
    let result = OpaqueClientRegistration::<Rfc9807Suite>::start(rng, password)?;
    Ok(ClientRegistrationStart {
        state: ClientRegistrationState::from_value(result.state),
        request: RegistrationRequest::from_value(&result.message)?,
    })
}

pub fn server_registration_start(
    server_setup: &ServerSetup,
    request: RegistrationRequest,
    binding: AccountBinding<'_>,
) -> Result<RegistrationResponse, Error> {
    let setup = server_setup.decode()?;
    let result = OpaqueServerRegistration::<Rfc9807Suite>::start(
        &setup,
        request.decode()?,
        binding.credential_identifier(),
    )?;
    RegistrationResponse::from_value(&result.message)
}

pub fn client_registration_finish<R>(
    rng: &mut R,
    state: ClientRegistrationState,
    password: &[u8],
    response: RegistrationResponse,
    binding: AccountBinding<'_>,
) -> Result<ClientRegistrationFinish, Error>
where
    R: CryptoRng + RngCore,
{
    validate_password(password)?;
    let ksf = password_ksf()?;
    let result = state.into_value().finish(
        rng,
        password,
        response.decode()?,
        OpaqueClientRegistrationFinishParameters::new(binding.identifiers(), Some(&ksf)),
    )?;
    // opaque-ke 的 FinishResult 本身不保证 Drop 时归零，必须先接管秘密再做可失败编码。
    let export_key_guard = Zeroizing::new(result.export_key);
    let upload = RegistrationUpload::from_value(&result.message)?;
    // 服务器完整失陷后仍可能离线猜测密码，因此 export key 不能进入 ARK 密钥链。
    drop(export_key_guard);
    Ok(ClientRegistrationFinish { upload })
}

pub fn server_registration_finish(upload: RegistrationUpload) -> Result<RegistrationRecord, Error> {
    let registration = OpaqueServerRegistration::<Rfc9807Suite>::finish(upload.decode()?);
    RegistrationRecord::from_value(&registration)
}

pub fn client_login_start<R>(rng: &mut R, password: &[u8]) -> Result<ClientLoginStart, Error>
where
    R: CryptoRng + RngCore,
{
    validate_password(password)?;
    let result = OpaqueClientLogin::<Rfc9807Suite>::start(rng, password)?;
    Ok(ClientLoginStart {
        state: ClientLoginState::from_value(result.state),
        request: CredentialRequest::from_value(&result.message)?,
    })
}

pub fn server_login_start<R>(
    rng: &mut R,
    server_setup: &ServerSetup,
    registration: Option<&RegistrationRecord>,
    request: CredentialRequest,
    binding: AccountBinding<'_>,
) -> Result<ServerLoginStart, Error>
where
    R: CryptoRng + RngCore,
{
    let setup = server_setup.decode()?;
    let password_file = registration.map(RegistrationRecord::decode).transpose()?;
    let result = OpaqueServerLogin::<Rfc9807Suite>::start(
        rng,
        &setup,
        password_file,
        request.decode()?,
        binding.credential_identifier(),
        OpaqueServerLoginParameters {
            context: Some(OPAQUE_CONTEXT),
            identifiers: binding.identifiers(),
        },
    )?;
    Ok(ServerLoginStart {
        state: ServerLoginState::from_value(result.state),
        response: CredentialResponse::from_value(&result.message)?,
    })
}

pub fn server_login_start_sealed<R>(
    rng: &mut R,
    server_setup: &ServerSetup,
    registration: Option<&RegistrationRecord>,
    request: CredentialRequest,
    binding: AccountBinding<'_>,
    continuation_key: &ServerLoginContinuationKey,
    continuation_aad: &[u8],
) -> Result<SealedServerLoginStart, Error>
where
    R: CryptoRng + RngCore,
{
    validate_continuation_aad(continuation_aad)?;
    let ServerLoginStart { state, response } =
        server_login_start(rng, server_setup, registration, request, binding)?;
    let continuation = seal_server_login_state(rng, state, continuation_key, continuation_aad)?;
    Ok(SealedServerLoginStart {
        response,
        continuation,
    })
}

pub fn client_login_finish<R>(
    rng: &mut R,
    state: ClientLoginState,
    password: &[u8],
    response: CredentialResponse,
    binding: AccountBinding<'_>,
) -> Result<ClientLoginFinish, Error>
where
    R: CryptoRng + RngCore,
{
    validate_password(password)?;
    let ksf = password_ksf()?;
    let result = state.into_value().finish(
        rng,
        password,
        response.decode()?,
        OpaqueClientLoginFinishParameters::new(
            Some(OPAQUE_CONTEXT),
            binding.identifiers(),
            Some(&ksf),
        ),
    )?;
    // 两份密钥先进入归零守卫，后续线消息编码异常也不能走普通数组析构。
    let session_key_guard = Zeroizing::new(result.session_key);
    let export_key_guard = Zeroizing::new(result.export_key);
    let finalization = CredentialFinalization::from_value(&result.message)?;
    let session_key = SessionKey::from_material(session_key_guard);
    // OPAQUE 只承担认证；设备根密钥必须继续由可信设备通道独立传递。
    drop(export_key_guard);
    Ok(ClientLoginFinish {
        finalization,
        session_key,
    })
}

pub fn server_login_finish(
    state: ServerLoginState,
    finalization: CredentialFinalization,
    binding: AccountBinding<'_>,
) -> Result<SessionKey, Error> {
    let result = state.into_value().finish(
        finalization.decode()?,
        OpaqueServerLoginParameters {
            context: Some(OPAQUE_CONTEXT),
            identifiers: binding.identifiers(),
        },
    )?;
    Ok(SessionKey::from_material(Zeroizing::new(
        result.session_key,
    )))
}

/// 验证密封 continuation 与 KE3，只返回认证结果。
///
/// 返回类型固定为 `Result<(), Error>`，不会向调用方提供 session key 或 export key：
///
/// ```
/// use kelivo_secure_core_protocol::{
///     AccountBinding, CredentialFinalization, Error, ServerLoginContinuation,
///     ServerLoginContinuationKey, server_login_finish_sealed,
/// };
///
/// let finish: for<'key, 'aad, 'binding> fn(
///     ServerLoginContinuation,
///     &'key ServerLoginContinuationKey,
///     &'aad [u8],
///     CredentialFinalization,
///     AccountBinding<'binding>,
/// ) -> Result<(), Error> = server_login_finish_sealed;
/// let _ = finish;
/// ```
pub fn server_login_finish_sealed(
    continuation: ServerLoginContinuation,
    continuation_key: &ServerLoginContinuationKey,
    continuation_aad: &[u8],
    finalization: CredentialFinalization,
    binding: AccountBinding<'_>,
) -> Result<(), Error> {
    let state = open_server_login_state(continuation, continuation_key, continuation_aad)?;
    let session_key = server_login_finish(state, finalization, binding)?;
    // OPAQUE 会话密钥只证明本次登录；内容密钥必须继续由可信设备链独立提供。
    drop(session_key);
    Ok(())
}

fn validate_continuation_aad(external_aad: &[u8]) -> Result<(), Error> {
    if external_aad.len() > MAX_SERVER_LOGIN_CONTINUATION_AAD_LENGTH {
        return Err(Error::ServerLoginContinuationAadTooLarge);
    }
    Ok(())
}

fn continuation_aad(header: &[u8], external_aad: &[u8]) -> Result<Vec<u8>, Error> {
    validate_continuation_aad(external_aad)?;
    let capacity = SERVER_LOGIN_CONTINUATION_AAD_DOMAIN
        .len()
        .checked_add(header.len())
        .and_then(|length| length.checked_add(external_aad.len()))
        .ok_or(Error::ServerLoginContinuationAadTooLarge)?;
    let mut aad = Vec::with_capacity(capacity);
    aad.extend_from_slice(SERVER_LOGIN_CONTINUATION_AAD_DOMAIN);
    aad.extend_from_slice(header);
    aad.extend_from_slice(external_aad);
    Ok(aad)
}

fn seal_server_login_state<R>(
    rng: &mut R,
    state: ServerLoginState,
    key: &ServerLoginContinuationKey,
    external_aad: &[u8],
) -> Result<ServerLoginContinuation, Error>
where
    R: CryptoRng + RngCore,
{
    let mut bytes = [0_u8; SERVER_LOGIN_CONTINUATION_LENGTH];
    bytes[..4].copy_from_slice(&SERVER_LOGIN_CONTINUATION_MAGIC);
    bytes[4..6].copy_from_slice(&SERVER_LOGIN_CONTINUATION_FORMAT_VERSION.to_be_bytes());
    bytes[6..8].copy_from_slice(&SERVER_LOGIN_CONTINUATION_CIPHER_SUITE_ID.to_be_bytes());

    let mut nonce_bytes = [0_u8; SERVER_LOGIN_CONTINUATION_NONCE_LENGTH];
    rng.try_fill_bytes(&mut nonce_bytes)
        .map_err(|_| Error::RandomnessUnavailable)?;
    bytes[SERVER_LOGIN_CONTINUATION_HEADER_LENGTH..SERVER_LOGIN_CONTINUATION_CIPHERTEXT_OFFSET]
        .copy_from_slice(&nonce_bytes);

    let aad = continuation_aad(
        &bytes[..SERVER_LOGIN_CONTINUATION_HEADER_LENGTH],
        external_aad,
    )?;
    let cipher = XChaCha20Poly1305::new_from_slice(key.as_bytes())
        .map_err(|_| Error::ServerLoginContinuationCrypto)?;
    let nonce = XNonce::from(nonce_bytes);
    let mut secret_state = Zeroizing::new(state.0.serialize());
    drop(state);
    debug_assert_eq!(secret_state.len(), SERVER_LOGIN_STATE_LENGTH);
    let tag = cipher
        .encrypt_inout_detached(&nonce, &aad, secret_state.as_mut_slice().into())
        .map_err(|_| Error::ServerLoginContinuationCrypto)?;
    bytes[SERVER_LOGIN_CONTINUATION_CIPHERTEXT_OFFSET..SERVER_LOGIN_CONTINUATION_TAG_OFFSET]
        .copy_from_slice(secret_state.as_slice());
    bytes[SERVER_LOGIN_CONTINUATION_TAG_OFFSET..].copy_from_slice(tag.as_slice());
    Ok(ServerLoginContinuation(bytes))
}

fn open_server_login_state(
    continuation: ServerLoginContinuation,
    key: &ServerLoginContinuationKey,
    external_aad: &[u8],
) -> Result<ServerLoginState, Error> {
    let aad = continuation_aad(
        &continuation.0[..SERVER_LOGIN_CONTINUATION_HEADER_LENGTH],
        external_aad,
    )?;
    let cipher = XChaCha20Poly1305::new_from_slice(key.as_bytes())
        .map_err(|_| Error::ServerLoginContinuationCrypto)?;
    let nonce_bytes: [u8; SERVER_LOGIN_CONTINUATION_NONCE_LENGTH] = continuation.0
        [SERVER_LOGIN_CONTINUATION_HEADER_LENGTH..SERVER_LOGIN_CONTINUATION_CIPHERTEXT_OFFSET]
        .try_into()
        .map_err(|_| Error::ServerLoginContinuationAuthenticationFailed)?;
    let nonce = XNonce::from(nonce_bytes);
    let mut secret_state = Zeroizing::new([0_u8; SERVER_LOGIN_STATE_LENGTH]);
    secret_state.copy_from_slice(
        &continuation.0
            [SERVER_LOGIN_CONTINUATION_CIPHERTEXT_OFFSET..SERVER_LOGIN_CONTINUATION_TAG_OFFSET],
    );
    let tag: &Tag = continuation.0[SERVER_LOGIN_CONTINUATION_TAG_OFFSET..]
        .try_into()
        .map_err(|_| Error::ServerLoginContinuationAuthenticationFailed)?;
    cipher
        .decrypt_inout_detached(&nonce, &aad, secret_state.as_mut_slice().into(), tag)
        .map_err(|_| Error::ServerLoginContinuationAuthenticationFailed)?;
    let state = OpaqueServerLogin::<Rfc9807Suite>::deserialize(secret_state.as_slice())?;
    Ok(ServerLoginState::from_value(state))
}

#[cfg(test)]
mod tests {
    use super::*;

    use opaque_ke::ksf::Identity;
    use opaque_ke::{
        ClientLogin, ClientLoginFinishParameters, ClientRegistration,
        ClientRegistrationFinishParameters, CredentialRequest as RfcCredentialRequest,
        Identifiers as RfcIdentifiers, RegistrationRequest as RfcRegistrationRequest, ServerLogin,
        ServerLoginParameters, ServerRegistration, ServerSetup as RfcServerSetup,
    };
    use rand::Error as RandomError;
    use sha2_opaque::{Digest, Sha512};
    use std::num::NonZeroU32;

    struct CycleRng {
        bytes: Vec<u8>,
    }

    impl CycleRng {
        fn new(bytes: Vec<u8>) -> Self {
            assert!(!bytes.is_empty());
            Self { bytes }
        }
    }

    impl RngCore for CycleRng {
        fn next_u32(&mut self) -> u32 {
            let mut bytes = [0_u8; 4];
            self.fill_bytes(&mut bytes);
            u32::from_le_bytes(bytes)
        }

        fn next_u64(&mut self) -> u64 {
            let mut bytes = [0_u8; 8];
            self.fill_bytes(&mut bytes);
            u64::from_le_bytes(bytes)
        }

        fn fill_bytes(&mut self, destination: &mut [u8]) {
            // RFC 上游夹具只写入一轮输入，目标缓冲区的剩余零值必须保持不变。
            let copied_length = self.bytes.len().min(destination.len());
            destination[..copied_length].copy_from_slice(&self.bytes[..copied_length]);
            self.bytes.rotate_left(copied_length);
        }

        fn try_fill_bytes(&mut self, destination: &mut [u8]) -> Result<(), RandomError> {
            self.fill_bytes(destination);
            Ok(())
        }
    }

    impl CryptoRng for CycleRng {}

    struct FailingRng;

    impl RngCore for FailingRng {
        fn next_u32(&mut self) -> u32 {
            0
        }

        fn next_u64(&mut self) -> u64 {
            0
        }

        fn fill_bytes(&mut self, destination: &mut [u8]) {
            destination.fill(0);
        }

        fn try_fill_bytes(&mut self, _destination: &mut [u8]) -> Result<(), RandomError> {
            let code = NonZeroU32::new(RandomError::CUSTOM_START).expect("随机错误码必须为非零值");
            Err(RandomError::from(code))
        }
    }

    struct SealFailingRng(CycleRng);

    impl RngCore for SealFailingRng {
        fn next_u32(&mut self) -> u32 {
            self.0.next_u32()
        }

        fn next_u64(&mut self) -> u64 {
            self.0.next_u64()
        }

        fn fill_bytes(&mut self, destination: &mut [u8]) {
            self.0.fill_bytes(destination);
        }

        fn try_fill_bytes(&mut self, _destination: &mut [u8]) -> Result<(), RandomError> {
            let code =
                NonZeroU32::new(RandomError::CUSTOM_START + 1).expect("随机错误码必须为非零值");
            Err(RandomError::from(code))
        }
    }

    impl CryptoRng for SealFailingRng {}

    struct PanicRng;

    impl RngCore for PanicRng {
        fn next_u32(&mut self) -> u32 {
            panic!("超限 AAD 必须在读取随机源前拒绝")
        }

        fn next_u64(&mut self) -> u64 {
            panic!("超限 AAD 必须在读取随机源前拒绝")
        }

        fn fill_bytes(&mut self, _destination: &mut [u8]) {
            panic!("超限 AAD 必须在读取随机源前拒绝")
        }

        fn try_fill_bytes(&mut self, _destination: &mut [u8]) -> Result<(), RandomError> {
            panic!("超限 AAD 必须在读取随机源前拒绝")
        }
    }

    impl CryptoRng for PanicRng {}

    fn deterministic_rng(seed: u8) -> CycleRng {
        CycleRng::new(
            (0_u16..=255)
                .map(|value| (value as u8).wrapping_add(seed))
                .collect(),
        )
    }

    fn registered_account() -> (ServerSetup, RegistrationRecord) {
        let binding = AccountBinding::new(b"sealed-account").expect("账户标识应有效");
        let password = b"sealed continuation password";
        let mut setup_rng = deterministic_rng(12);
        let setup = generate_server_setup(&mut setup_rng).expect("服务端初始化应成功");
        let mut registration_rng = deterministic_rng(22);
        let (state, request) = client_registration_start(&mut registration_rng, password)
            .expect("注册起始应成功")
            .into_parts();
        let response =
            server_registration_start(&setup, request, binding).expect("服务端注册响应应成功");
        let mut finish_rng = deterministic_rng(32);
        let upload =
            client_registration_finish(&mut finish_rng, state, password, response, binding)
                .expect("客户端注册完成应成功")
                .into_upload();
        let record = server_registration_finish(upload).expect("服务端保存记录应成功");
        (setup, record)
    }

    #[test]
    fn sealed_server_login_round_trip_uses_fixed_public_continuation() {
        let (setup, record) = registered_account();
        let binding = AccountBinding::new(b"sealed-account").expect("账户标识应有效");
        let password = b"sealed continuation password";
        let continuation_key =
            ServerLoginContinuationKey::from_bytes(&[0x31; SERVER_LOGIN_CONTINUATION_KEY_LENGTH])
                .expect("固定长度密封密钥应有效");
        let continuation_aad = b"login-attempt/018f6d5e";

        let mut client_start_rng = deterministic_rng(42);
        let (client_state, request) = client_login_start(&mut client_start_rng, password)
            .expect("客户端登录起始应成功")
            .into_parts();
        let mut server_start_rng = deterministic_rng(52);
        let (response, continuation) = server_login_start_sealed(
            &mut server_start_rng,
            &setup,
            Some(&record),
            request,
            binding,
            &continuation_key,
            continuation_aad,
        )
        .expect("服务端应返回密封登录状态")
        .into_parts();
        assert_eq!(
            continuation.as_bytes().len(),
            SERVER_LOGIN_CONTINUATION_LENGTH
        );

        let mut client_finish_rng = deterministic_rng(62);
        let finalization = client_login_finish(
            &mut client_finish_rng,
            client_state,
            password,
            response,
            binding,
        )
        .expect("正确密码应生成最终确认")
        .into_finalization();
        server_login_finish_sealed(
            continuation,
            &continuation_key,
            continuation_aad,
            finalization,
            binding,
        )
        .expect("正确密钥与 AAD 应完成认证");
    }

    fn sealed_login_attempt_with_aad(continuation_aad: &[u8]) -> (Vec<u8>, Vec<u8>) {
        let (setup, record) = registered_account();
        let binding = AccountBinding::new(b"sealed-account").expect("账户标识应有效");
        let password = b"sealed continuation password";
        let continuation_key =
            ServerLoginContinuationKey::from_bytes(&[0x31; SERVER_LOGIN_CONTINUATION_KEY_LENGTH])
                .expect("固定长度密封密钥应有效");
        let mut client_start_rng = deterministic_rng(72);
        let (client_state, request) = client_login_start(&mut client_start_rng, password)
            .expect("客户端登录起始应成功")
            .into_parts();
        let mut server_start_rng = deterministic_rng(82);
        let (response, continuation) = server_login_start_sealed(
            &mut server_start_rng,
            &setup,
            Some(&record),
            request,
            binding,
            &continuation_key,
            continuation_aad,
        )
        .expect("服务端应返回密封登录状态")
        .into_parts();
        let mut client_finish_rng = deterministic_rng(92);
        let finalization = client_login_finish(
            &mut client_finish_rng,
            client_state,
            password,
            response,
            binding,
        )
        .expect("正确密码应生成最终确认")
        .into_finalization();
        (
            continuation.as_bytes().to_vec(),
            finalization.as_bytes().to_vec(),
        )
    }

    fn sealed_login_attempt() -> (Vec<u8>, Vec<u8>) {
        sealed_login_attempt_with_aad(b"login-attempt/failure-cases")
    }

    fn finish_sealed_attempt(
        continuation: &[u8],
        key: &[u8],
        aad: &[u8],
        finalization: &[u8],
    ) -> Result<(), Error> {
        server_login_finish_sealed(
            ServerLoginContinuation::from_bytes(continuation)?,
            &ServerLoginContinuationKey::from_bytes(key)?,
            aad,
            CredentialFinalization::from_bytes(finalization)?,
            AccountBinding::new(b"sealed-account")?,
        )
    }

    fn assert_continuation_tampering_fails(index: usize) {
        let (mut continuation, finalization) = sealed_login_attempt();
        let key = [0x31; SERVER_LOGIN_CONTINUATION_KEY_LENGTH];
        let aad = b"login-attempt/failure-cases";
        continuation[index] ^= 1;
        assert_eq!(
            finish_sealed_attempt(&continuation, &key, aad, &finalization),
            Err(Error::ServerLoginContinuationAuthenticationFailed)
        );
    }

    #[test]
    fn sealed_server_login_rejects_nonce_tampering() {
        assert_continuation_tampering_fails(SERVER_LOGIN_CONTINUATION_HEADER_LENGTH);
    }

    #[test]
    fn sealed_server_login_rejects_ciphertext_tampering() {
        assert_continuation_tampering_fails(SERVER_LOGIN_CONTINUATION_CIPHERTEXT_OFFSET);
    }

    #[test]
    fn sealed_server_login_rejects_tag_tampering() {
        assert_continuation_tampering_fails(SERVER_LOGIN_CONTINUATION_TAG_OFFSET);
    }

    #[test]
    fn sealed_server_login_rejects_wrong_context_and_wrong_ke3() {
        let (continuation, finalization) = sealed_login_attempt();
        let key = [0x31; SERVER_LOGIN_CONTINUATION_KEY_LENGTH];
        let aad = b"login-attempt/failure-cases";
        let wrong_key = [0x32; SERVER_LOGIN_CONTINUATION_KEY_LENGTH];
        assert_eq!(
            finish_sealed_attempt(&continuation, &wrong_key, aad, &finalization),
            Err(Error::ServerLoginContinuationAuthenticationFailed)
        );
        assert_eq!(
            finish_sealed_attempt(&continuation, &key, b"login-attempt/other", &finalization,),
            Err(Error::ServerLoginContinuationAuthenticationFailed)
        );

        let mut wrong_finalization = finalization.clone();
        let last = wrong_finalization
            .last_mut()
            .expect("固定 KE3 必须包含客户端 MAC");
        *last ^= 1;
        assert!(matches!(
            finish_sealed_attempt(&continuation, &key, aad, &wrong_finalization),
            Err(Error::Opaque(OpaqueProtocolError::InvalidLoginError))
        ));
    }

    #[test]
    fn sealed_server_login_reports_continuation_rng_failure() {
        let (setup, record) = registered_account();
        let binding = AccountBinding::new(b"sealed-account").expect("账户标识应有效");
        let mut client_rng = deterministic_rng(102);
        let (_, request) = client_login_start(&mut client_rng, b"sealed continuation password")
            .expect("客户端登录起始应成功")
            .into_parts();
        let key =
            ServerLoginContinuationKey::from_bytes(&[0x31; SERVER_LOGIN_CONTINUATION_KEY_LENGTH])
                .expect("固定长度密封密钥应有效");
        let mut rng = SealFailingRng(deterministic_rng(112));

        assert_eq!(
            server_login_start_sealed(
                &mut rng,
                &setup,
                Some(&record),
                request,
                binding,
                &key,
                b"login-attempt/rng-failure",
            )
            .err(),
            Some(Error::RandomnessUnavailable)
        );
    }

    #[test]
    fn sealed_server_login_accepts_exact_aad_limit() {
        let aad = vec![0x5a; MAX_SERVER_LOGIN_CONTINUATION_AAD_LENGTH];
        let (continuation, finalization) = sealed_login_attempt_with_aad(&aad);
        finish_sealed_attempt(
            &continuation,
            &[0x31; SERVER_LOGIN_CONTINUATION_KEY_LENGTH],
            &aad,
            &finalization,
        )
        .expect("恰好 64 KiB 的 AAD 应完成认证");
    }

    #[test]
    fn sealed_server_login_rejects_oversized_aad_before_rng() {
        let (setup, record) = registered_account();
        let binding = AccountBinding::new(b"sealed-account").expect("账户标识应有效");
        let mut client_rng = deterministic_rng(122);
        let (_, request) = client_login_start(&mut client_rng, b"sealed continuation password")
            .expect("客户端登录起始应成功")
            .into_parts();
        let key =
            ServerLoginContinuationKey::from_bytes(&[0x31; SERVER_LOGIN_CONTINUATION_KEY_LENGTH])
                .expect("固定长度密封密钥应有效");
        let oversized_aad = vec![0_u8; MAX_SERVER_LOGIN_CONTINUATION_AAD_LENGTH + 1];
        let mut rng = PanicRng;

        assert_eq!(
            server_login_start_sealed(
                &mut rng,
                &setup,
                Some(&record),
                request,
                binding,
                &key,
                &oversized_aad,
            )
            .err(),
            Some(Error::ServerLoginContinuationAadTooLarge)
        );
    }

    #[test]
    fn sealed_server_login_public_values_enforce_every_length_boundary() {
        fn require_zeroizing_key<T: Zeroize + ZeroizeOnDrop>() {}

        require_zeroizing_key::<ServerLoginContinuationKey>();
        assert_eq!(SERVER_LOGIN_CONTINUATION_FORMAT_VERSION, 1);
        assert_eq!(SERVER_LOGIN_CONTINUATION_CIPHER_SUITE_ID, 1);
        assert_eq!(SERVER_LOGIN_CONTINUATION_KEY_LENGTH, 32);
        assert_eq!(SERVER_LOGIN_CONTINUATION_LENGTH, 176);

        assert_eq!(
            ServerLoginContinuationKey::from_bytes(&[0_u8; 31]).err(),
            Some(Error::InvalidServerLoginContinuationKeyLength {
                expected: 32,
                actual: 31,
            })
        );
        assert_eq!(
            ServerLoginContinuationKey::from_bytes(&[0_u8; 33]).err(),
            Some(Error::InvalidServerLoginContinuationKeyLength {
                expected: 32,
                actual: 33,
            })
        );

        let mut valid_shape = [0_u8; 176];
        valid_shape[..4].copy_from_slice(b"KOSC");
        valid_shape[4..6].copy_from_slice(&1_u16.to_be_bytes());
        valid_shape[6..8].copy_from_slice(&1_u16.to_be_bytes());
        ServerLoginContinuation::from_bytes(&valid_shape).expect("固定格式外壳应可解析");

        let mut invalid_magic = valid_shape;
        invalid_magic[0] ^= 1;
        assert_eq!(
            ServerLoginContinuation::from_bytes(&invalid_magic).err(),
            Some(Error::InvalidServerLoginContinuationMagic)
        );
        let mut unsupported_version = valid_shape;
        unsupported_version[4..6].copy_from_slice(&2_u16.to_be_bytes());
        assert_eq!(
            ServerLoginContinuation::from_bytes(&unsupported_version).err(),
            Some(Error::UnsupportedServerLoginContinuationVersion(2))
        );
        let mut unsupported_cipher_suite = valid_shape;
        unsupported_cipher_suite[6..8].copy_from_slice(&2_u16.to_be_bytes());
        assert_eq!(
            ServerLoginContinuation::from_bytes(&unsupported_cipher_suite).err(),
            Some(Error::UnsupportedServerLoginContinuationCipherSuite(2))
        );

        assert_eq!(
            ServerLoginContinuation::from_bytes(&valid_shape[..175]).err(),
            Some(Error::InvalidServerLoginContinuationLength {
                expected: 176,
                actual: 175,
            })
        );
        let mut too_long = valid_shape.to_vec();
        too_long.push(0);
        assert_eq!(
            ServerLoginContinuation::from_bytes(&too_long).err(),
            Some(Error::InvalidServerLoginContinuationLength {
                expected: 176,
                actual: 177,
            })
        );
    }

    fn decode_hex(value: &str) -> Vec<u8> {
        let digits: Vec<u8> = value
            .bytes()
            .filter(|byte| !byte.is_ascii_whitespace())
            .collect();
        assert_eq!(digits.len() % 2, 0);
        digits
            .chunks_exact(2)
            .map(|pair| (hex_nibble(pair[0]) << 4) | hex_nibble(pair[1]))
            .collect()
    }

    fn hex_nibble(value: u8) -> u8 {
        match value {
            b'0'..=b'9' => value - b'0',
            b'a'..=b'f' => value - b'a' + 10,
            b'A'..=b'F' => value - b'A' + 10,
            _ => panic!("测试向量包含非十六进制字符"),
        }
    }

    #[test]
    fn production_profile_is_explicit_and_not_argon2_default() {
        let ksf = password_ksf().expect("固定参数必须有效");
        assert_eq!(PROTOCOL_PROFILE.format_version, 1);
        assert_eq!(PROTOCOL_PROFILE.ciphersuite_id, 1);
        assert_eq!(PROTOCOL_PROFILE.password_profile_id, 1);
        assert_eq!(SERVER_SETUP_LENGTH, 144);
        assert_eq!(REGISTRATION_RECORD_LENGTH, 208);
        assert_eq!(ksf.params().m_cost(), 65_536);
        assert_eq!(ksf.params().t_cost(), 3);
        assert_eq!(ksf.params().p_cost(), 4);
        assert_eq!(ksf.params().output_len(), Some(64));
    }

    #[test]
    fn random_source_failure_is_closed_without_deterministic_fallback() {
        assert_eq!(
            probe_random_source(FailingRng).err(),
            Some(Error::RandomnessUnavailable)
        );
    }

    #[test]
    fn wire_envelope_rejects_every_version_and_length_boundary() {
        let mut rng = deterministic_rng(1);
        let request = client_registration_start(&mut rng, b"wire-boundary-password")
            .expect("注册起始应成功")
            .request;
        let valid = request.as_bytes().to_vec();
        RegistrationRequest::from_bytes(&valid).expect("原始外壳应可解析");

        let mut invalid = valid.clone();
        invalid[0] ^= 1;
        assert_eq!(
            RegistrationRequest::from_bytes(&invalid).err(),
            Some(Error::InvalidMagic)
        );

        let mut invalid = valid.clone();
        invalid[4..6].copy_from_slice(&2_u16.to_be_bytes());
        assert_eq!(
            RegistrationRequest::from_bytes(&invalid).err(),
            Some(Error::UnsupportedFormatVersion(2))
        );

        let mut invalid = valid.clone();
        invalid[6..8].copy_from_slice(&2_u16.to_be_bytes());
        assert_eq!(
            RegistrationRequest::from_bytes(&invalid).err(),
            Some(Error::UnsupportedCipherSuite(2))
        );

        let mut invalid = valid.clone();
        invalid[8..10].copy_from_slice(&2_u16.to_be_bytes());
        assert_eq!(
            RegistrationRequest::from_bytes(&invalid).err(),
            Some(Error::UnsupportedPasswordProfile(2))
        );

        let mut invalid = valid.clone();
        invalid[10] = ObjectKind::CredentialRequest.id();
        assert_eq!(
            RegistrationRequest::from_bytes(&invalid).err(),
            Some(Error::UnexpectedObjectKind {
                expected: ObjectKind::RegistrationRequest.id(),
                actual: ObjectKind::CredentialRequest.id(),
            })
        );

        let mut invalid = valid.clone();
        invalid[11] = 1;
        assert_eq!(
            RegistrationRequest::from_bytes(&invalid).err(),
            Some(Error::UnsupportedFlags(1))
        );

        let mut invalid = valid.clone();
        invalid[12..16].copy_from_slice(&31_u32.to_be_bytes());
        assert_eq!(
            RegistrationRequest::from_bytes(&invalid).err(),
            Some(Error::InvalidPayloadLength {
                expected: 32,
                actual: 31,
            })
        );

        let mut invalid = valid.clone();
        invalid.pop();
        assert_eq!(
            RegistrationRequest::from_bytes(&invalid).err(),
            Some(Error::InvalidWireLength {
                expected: valid.len(),
                actual: valid.len() - 1,
            })
        );

        let mut invalid = valid.clone();
        invalid.push(0);
        assert_eq!(
            RegistrationRequest::from_bytes(&invalid).err(),
            Some(Error::InvalidWireLength {
                expected: valid.len(),
                actual: valid.len() + 1,
            })
        );
    }

    #[test]
    fn production_profile_fixed_rng_wire_is_stable_and_authenticates() {
        let binding = AccountBinding::new(b"account-0001").expect("账户标识应有效");
        let password = b"correct horse battery staple";
        let mut wire_digest = Sha512::new();

        let mut setup_rng = deterministic_rng(11);
        let setup = generate_server_setup(&mut setup_rng).expect("服务端初始化应成功");
        assert_eq!(setup.as_bytes().len(), SERVER_SETUP_LENGTH);
        wire_digest.update(setup.as_bytes());
        let setup = ServerSetup::from_bytes(setup.as_bytes()).expect("服务端配置线格式应可往返");

        let mut registration_rng = deterministic_rng(21);
        let registration =
            client_registration_start(&mut registration_rng, password).expect("注册起始应成功");
        let registration_state_bytes = registration
            .state
            .wire_bytes_for_test()
            .expect("客户端注册状态测试线格式应可编码");
        wire_digest.update(registration_state_bytes.as_slice());
        wire_digest.update(registration.request.as_bytes());
        let registration_state =
            ClientRegistrationState::from_wire_bytes_for_test(registration_state_bytes.as_slice())
                .expect("客户端注册状态测试线格式应可往返");
        let registration_request = RegistrationRequest::from_bytes(registration.request.as_bytes())
            .expect("注册请求线格式应可往返");
        let response = server_registration_start(&setup, registration_request, binding)
            .expect("服务端注册响应应成功");
        wire_digest.update(response.as_bytes());
        let response =
            RegistrationResponse::from_bytes(response.as_bytes()).expect("注册响应线格式应可往返");
        let mut registration_finish_rng = deterministic_rng(31);
        let registration_finish = client_registration_finish(
            &mut registration_finish_rng,
            registration_state,
            password,
            response,
            binding,
        )
        .expect("客户端注册完成应成功");
        wire_digest.update(registration_finish.upload.as_bytes());
        let upload = RegistrationUpload::from_bytes(registration_finish.upload.as_bytes())
            .expect("注册上传线格式应可往返");
        let record = server_registration_finish(upload).expect("服务端保存记录应成功");
        assert_eq!(record.as_bytes().len(), REGISTRATION_RECORD_LENGTH);
        wire_digest.update(record.as_bytes());
        let record =
            RegistrationRecord::from_bytes(record.as_bytes()).expect("注册记录线格式应可往返");

        let mut login_rng = deterministic_rng(41);
        let login = client_login_start(&mut login_rng, password).expect("登录起始应成功");
        let client_login_state_bytes = login
            .state
            .wire_bytes_for_test()
            .expect("客户端登录状态测试线格式应可编码");
        wire_digest.update(client_login_state_bytes.as_slice());
        wire_digest.update(login.request.as_bytes());
        let login_state =
            ClientLoginState::from_wire_bytes_for_test(client_login_state_bytes.as_slice())
                .expect("客户端登录状态测试线格式应可往返");
        let login_request = CredentialRequest::from_bytes(login.request.as_bytes())
            .expect("凭据请求线格式应可往返");
        let mut server_login_rng = deterministic_rng(51);
        let server_login = server_login_start(
            &mut server_login_rng,
            &setup,
            Some(&record),
            login_request,
            binding,
        )
        .expect("服务端登录响应应成功");
        let server_login_state_bytes = server_login
            .state
            .wire_bytes_for_test()
            .expect("服务端登录状态测试线格式应可编码");
        wire_digest.update(server_login_state_bytes.as_slice());
        wire_digest.update(server_login.response.as_bytes());
        let server_login_state =
            ServerLoginState::from_wire_bytes_for_test(server_login_state_bytes.as_slice())
                .expect("服务端登录状态测试线格式应可往返");
        let login_response = CredentialResponse::from_bytes(server_login.response.as_bytes())
            .expect("凭据响应线格式应可往返");
        let mut login_finish_rng = deterministic_rng(61);
        let client_finish = client_login_finish(
            &mut login_finish_rng,
            login_state,
            password,
            login_response,
            binding,
        )
        .expect("客户端登录完成应成功");
        let ClientLoginFinish {
            finalization,
            session_key: client_session_key,
        } = client_finish;
        wire_digest.update(finalization.as_bytes());
        let finalization = CredentialFinalization::from_bytes(finalization.as_bytes())
            .expect("凭据确认线格式应可往返");
        let stable_wire_digest = wire_digest.finalize();
        // 固定摘要让线格式、对象顺序或底层序列化的任何漂移都必须显式升级版本。
        assert_eq!(
            stable_wire_digest.as_slice(),
            decode_hex(
                "
                0541bd37dbc0de48ffad6c19d58fd9ec428af8e82095d98a8b38a46cc625fce2
                6b6dd02b3b14a0d48320f48c1ce868dc30cecbdad3a50e44e9c62c03af8a6706
                "
            )
        );
        let server_session_key = server_login_finish(server_login_state, finalization, binding)
            .expect("服务端认证完成应成功");
        assert_eq!(client_session_key.as_bytes(), server_session_key.as_bytes());

        let mut wrong_login_rng = deterministic_rng(71);
        let wrong_login = client_login_start(&mut wrong_login_rng, b"definitely-wrong-password")
            .expect("错误密码仍应生成不可区分的首包");
        let mut wrong_server_rng = deterministic_rng(81);
        let wrong_server = server_login_start(
            &mut wrong_server_rng,
            &setup,
            Some(&record),
            wrong_login.request,
            binding,
        )
        .expect("服务端不得在首轮泄露密码是否正确");
        let mut wrong_finish_rng = deterministic_rng(91);
        assert!(matches!(
            client_login_finish(
                &mut wrong_finish_rng,
                wrong_login.state,
                b"definitely-wrong-password",
                wrong_server.response,
                binding,
            ),
            Err(Error::Opaque(OpaqueProtocolError::InvalidLoginError))
        ));

        let missing_binding = AccountBinding::new(b"missing-account").expect("账户标识应有效");
        let mut missing_login_rng = deterministic_rng(101);
        let missing_login =
            client_login_start(&mut missing_login_rng, password).expect("未知账户仍应生成登录请求");
        let mut missing_server_rng = deterministic_rng(111);
        let missing_response = server_login_start(
            &mut missing_server_rng,
            &setup,
            None,
            missing_login.request,
            missing_binding,
        )
        .expect("未知账户必须返回不可区分的假响应");
        assert_eq!(
            missing_response.response.as_bytes().len(),
            WIRE_HEADER_LENGTH + ObjectKind::CredentialResponse.payload_length()
        );
    }

    #[test]
    fn public_api_does_not_expose_opaque_export_key_or_root_key_wrapping() {
        let source = include_str!("lib.rs");
        let production_source = source
            .split("mod tests {")
            .next()
            .expect("生产源码边界必须存在");
        for forbidden in [
            "pub struct Rfc9807Suite",
            "pub struct ExportKey",
            "pub export_key:",
            "pub fn wrap_",
            "pub fn encrypt_root",
            "pub fn decrypt_root",
        ] {
            assert!(
                !production_source.contains(forbidden),
                "生产 API 禁止出现：{forbidden}"
            );
        }
        let registration_finish_source = production_source
            .split("pub fn client_registration_finish")
            .nth(1)
            .and_then(|source| source.split("pub fn server_registration_finish").next())
            .expect("客户端注册完成函数边界必须存在");
        assert!(
            registration_finish_source
                .find("Zeroizing::new(result.export_key)")
                .expect("注册 export key 必须进入归零守卫")
                < registration_finish_source
                    .find("RegistrationUpload::from_value")
                    .expect("注册上传消息编码必须存在")
        );

        let login_finish_source = production_source
            .split("pub fn client_login_finish")
            .nth(1)
            .and_then(|source| source.split("pub fn server_login_finish").next())
            .expect("客户端登录完成函数边界必须存在");
        let finalization_position = login_finish_source
            .find("CredentialFinalization::from_value")
            .expect("登录完成消息编码必须存在");
        for secret in [
            "Zeroizing::new(result.session_key)",
            "Zeroizing::new(result.export_key)",
        ] {
            assert!(
                login_finish_source
                    .find(secret)
                    .unwrap_or_else(|| panic!("{secret} 必须进入归零守卫"))
                    < finalization_position,
                "{secret} 必须早于任何可失败线消息编码"
            );
        }
        assert_eq!(
            production_source
                .matches("pub struct SessionKey(Zeroizing<Vec<u8>>);")
                .count(),
            1
        );
    }

    #[test]
    fn secret_states_cannot_restore_public_byte_interfaces() {
        let source = include_str!("lib.rs");
        let production_source = source
            .split("mod tests {")
            .next()
            .expect("生产源码边界必须存在");
        let normalized: String = production_source.split_whitespace().collect();
        let secret_macro = normalized
            .split("macro_rules!define_secret_state{")
            .nth(1)
            .and_then(|source| source.split("define_wire_object!(ServerSetup").next())
            .expect("秘密状态宏边界必须存在");

        assert!(!secret_macro.contains("pubfn"));
        assert!(secret_macro.contains("#[cfg(test)]fnfrom_wire_bytes_for_test"));
        assert!(secret_macro.contains("#[cfg(test)]fnwire_bytes_for_test"));

        for state in [
            "ClientRegistrationState",
            "ClientLoginState",
            "ServerLoginState",
        ] {
            assert!(
                normalized.contains(&format!("define_secret_state!({state},")),
                "{state} 必须使用秘密状态接口"
            );
            assert!(
                !normalized.contains(&format!("define_wire_object!({state},")),
                "{state} 禁止恢复公开线对象接口"
            );
        }
        assert_eq!(normalized.matches("define_secret_state!(").count(), 3);
    }

    struct Rfc9807IdentitySuite;

    impl CipherSuite for Rfc9807IdentitySuite {
        type OprfCs = Ristretto255;
        type KeyExchange = TripleDh<Ristretto255, sha2_opaque::Sha512>;
        // RFC 向量固定使用 Identity；生产套件始终使用显式 Argon2id profile。
        type Ksf = Identity;
    }

    struct RfcRealVector {
        client_identity: Option<&'static str>,
        server_identity: Option<&'static str>,
        registration_upload: &'static str,
        ke2: &'static str,
        ke3: &'static str,
        session_key: &'static str,
    }

    const RFC_CONTEXT: &str = "4f50415155452d504f43";
    const RFC_OPRF_SEED: &str = "
        f433d0227b0b9dd54f7c4422b600e764e47fb503f1f9a0f0a47c6606b0
        54a7fdc65347f1a08f277e22358bbabe26f823fca82c7848e9a75661f4ec5d5c1989e
        f
    ";
    const RFC_CREDENTIAL_IDENTIFIER: &str = "31323334";
    const RFC_PASSWORD: &str = "436f7272656374486f72736542617474657279537461706c65";
    const RFC_ENVELOPE_NONCE: &str = "
        ac13171b2f17bc2c74997f0fce1e1f35bec6b91fe2e12dbd323d23ba7a38dfec
    ";
    const RFC_MASKING_NONCE: &str = "
        38fe59af0df2c79f57b8780278f5ae47355fe1f817119041951c80f612fdfc6d
    ";
    const RFC_SERVER_PRIVATE_KEY: &str = "
        47451a85372f8b3537e249d7b54188091fb18edde78094b43e2ba42b5eb89f0d
    ";
    const RFC_SERVER_PUBLIC_KEY: &str = "
        b2fe7af9f48cc502d016729d2fe25cdd433f2c4bc904660b2a382c9b79df1a78
    ";
    const RFC_SERVER_NONCE: &str = "
        71cd9960ecef2fe0d0f7494986fa3d8b2bb01963537e60efb13981e138e3d4a1
    ";
    const RFC_CLIENT_NONCE: &str = "
        da7e07376d6d6f034cfa9bb537d11b8c6b4238c334333d1f0aebb380cae6a6cc
    ";
    const RFC_CLIENT_KEYSHARE_SEED: &str = "
        82850a697b42a505f5b68fcdafce8c31f0af2b581f063cf1091933541936304b
    ";
    const RFC_SERVER_KEYSHARE_SEED: &str = "
        05a4f54206eef1ba2f615bc0aa285cb22f26d1153b5b40a1e85ff80da12f982f
    ";
    const RFC_BLIND_REGISTRATION: &str = "
        76cfbfe758db884bebb33582331ba9f159720ca8784a2a070a265d9c2d6abe01
    ";
    const RFC_BLIND_LOGIN: &str = "
        6ecc102d2e7a7cf49617aad7bbe188556792d4acd60a1a8a8d2b65d4b0790308
    ";
    const RFC_REGISTRATION_REQUEST: &str = "
        5059ff249eb1551b7ce4991f3336205bde44a105a032e747d21bf382e75f7a71
    ";
    const RFC_REGISTRATION_RESPONSE: &str = "
        7408a268083e03abc7097fc05b587834539065e86fb0c7b6342fcf5e01e5b019
        b2fe7af9f48cc502d016729d2fe25cdd433f2c4bc904660b2a382c9b79df1a78
    ";
    const RFC_KE1: &str = "
        c4dedb0ba6ed5d965d6f250fbe554cd45cba5dfcce3ce836e4aee778aa3cd44d
        da7e07376d6d6f034cfa9bb537d11b8c6b4238c334333d1f0aebb380cae6a6cc
        6e29bee50701498605b2c085d7b241ca15ba5c32027dd21ba420b94ce60da326
    ";
    const RFC_EXPORT_KEY: &str = "
        1ef15b4fa99e8a852412450ab78713aad30d21fa6966c9b8c9fb3262a970dc62
        950d4dd4ed62598229b1b72794fc0335199d9f7fcc6eaedde92cc04870e63f16
    ";

    const RFC_REAL_VECTOR_1: RfcRealVector = RfcRealVector {
        client_identity: None,
        server_identity: None,
        registration_upload: "
            76a845464c68a5d2f7e442436bb1424953b17d3e2e289ccba
            ccafb57ac5c36751ac5844383c7708077dea41cbefe2fa15724f449e535dd7dd562e
            66f5ecfb95864eadddec9db5874959905117dad40a4524111849799281fefe3c51fa8
            2785c5ac13171b2f17bc2c74997f0fce1e1f35bec6b91fe2e12dbd323d23ba7a38dfe
            c634b0f5b96109c198a8027da51854c35bee90d1e1c781806d07d49b76de6a28b8d9e
            9b6c93b9f8b64d16dddd9c5bfb5fea48ee8fd2f75012a8b308605cdd8ba5
        ",
        ke2: "
            7e308140890bcde30cbcea28b01ea1ecfbd077cff62c4def8efa075aabcbb471
            38fe59af0df2c79f57b8780278f5ae47355fe1f817119041951c80f612fdfc6dd6ec6
            0bcdb26dc455ddf3e718f1020490c192d70dfc7e403981179d8073d1146a4f9aa1ced
            4e4cd984c657eb3b54ced3848326f70331953d91b02535af44d9fedc80188ca46743c
            52786e0382f95ad85c08f6afcd1ccfbff95e2bdeb015b166c6b20b92f832cc6df01e0
            b86a7efd92c1c804ff865781fa93f2f20b446c8371b671cd9960ecef2fe0d0f749498
            6fa3d8b2bb01963537e60efb13981e138e3d4a1c4f62198a9d6fa9170c42c3c71f197
            1b29eb1d5d0bd733e40816c91f7912cc4a660c48dae03e57aaa38f3d0cffcfc21852e
            bc8b405d15bd6744945ba1a93438a162b6111699d98a16bb55b7bdddfe0fc5608b23d
            a246e7bd73b47369169c5c90
        ",
        ke3: "
            4455df4f810ac31a6748835888564b536e6da5d9944dfea9e34defb9575fe5e2
            661ef61d2ae3929bcf57e53d464113d364365eb7d1a57b629707ca48da18e442
        ",
        session_key: "
            42afde6f5aca0cfa5c163763fbad55e73a41db6b41bc87b8e7b62214a8eedc67
            31fa3cb857d657ab9b3764b89a84e91ebcb4785166fbb02cedfcbdfda215b96f
        ",
    };

    const RFC_REAL_VECTOR_2: RfcRealVector = RfcRealVector {
        client_identity: Some("616c696365"),
        server_identity: Some("626f62"),
        registration_upload: "
            76a845464c68a5d2f7e442436bb1424953b17d3e2e289ccba
            ccafb57ac5c36751ac5844383c7708077dea41cbefe2fa15724f449e535dd7dd562e
            66f5ecfb95864eadddec9db5874959905117dad40a4524111849799281fefe3c51fa8
            2785c5ac13171b2f17bc2c74997f0fce1e1f35bec6b91fe2e12dbd323d23ba7a38dfe
            c1ac902dc5589e9a5f0de56ad685ea8486210ef41449cd4d8712828913c5d2b680b2b
            3af4a26c765cff329bfb66d38ecf1d6cfa9e7a73c222c6efe0d9520f7d7c
        ",
        ke2: "
            7e308140890bcde30cbcea28b01ea1ecfbd077cff62c4def8efa075aabcbb471
            38fe59af0df2c79f57b8780278f5ae47355fe1f817119041951c80f612fdfc6dd6ec6
            0bcdb26dc455ddf3e718f1020490c192d70dfc7e403981179d8073d1146a4f9aa1ced
            4e4cd984c657eb3b54ced3848326f70331953d91b02535af44d9fea502150b67fe367
            95dd8914f164e49f81c7688a38928372134b7dccd50e09f8fed9518b7b2f94835b3c4
            fe4c8475e7513f20eb97ff0568a39caee3fd6251876f71cd9960ecef2fe0d0f749498
            6fa3d8b2bb01963537e60efb13981e138e3d4a1c4f62198a9d6fa9170c42c3c71f197
            1b29eb1d5d0bd733e40816c91f7912cc4a292371e7809a9031743e943fb3b56f51de9
            03552fc91fba4e7419029951c3970b2e2f0a9dea218d22e9e4e0000855bb6421aa361
            0d6fc0f4033a6517030d4341
        ",
        ke3: "
            7a026de1d6126905736c3f6d92463a08d209833eb793e46d0f7f15b3e0f62c76
            43763c02bbc6b8d3d15b63250cae98171e9260f1ffa789750f534ac11a0176d5
        ",
        session_key: "
            ae7951123ab5befc27e62e63f52cf472d6236cb386c968cc47b7e34f866aa4bc
            7638356a73cfce92becf39d6a7d32a1861f12130e824241fe6cab34fbd471a57
        ",
    };

    fn run_rfc_real_vector(vector: &RfcRealVector) -> Result<(), OpaqueProtocolError> {
        let context = decode_hex(RFC_CONTEXT);
        let credential_identifier = decode_hex(RFC_CREDENTIAL_IDENTIFIER);
        let password = decode_hex(RFC_PASSWORD);
        let client_identity = vector.client_identity.map(decode_hex);
        let server_identity = vector.server_identity.map(decode_hex);

        let server_public_key = decode_hex(RFC_SERVER_PUBLIC_KEY);
        let server_setup_bytes = [
            decode_hex(RFC_OPRF_SEED),
            decode_hex(RFC_SERVER_PRIVATE_KEY),
            server_public_key.clone(),
        ]
        .concat();
        let server_setup =
            RfcServerSetup::<Rfc9807IdentitySuite>::deserialize(&server_setup_bytes)?;

        let mut registration_rng = CycleRng::new(decode_hex(RFC_BLIND_REGISTRATION));
        let registration =
            ClientRegistration::<Rfc9807IdentitySuite>::start(&mut registration_rng, &password)?;
        assert_eq!(
            registration.message.serialize().as_slice(),
            decode_hex(RFC_REGISTRATION_REQUEST)
        );

        let registration_response = ServerRegistration::<Rfc9807IdentitySuite>::start(
            &server_setup,
            RfcRegistrationRequest::deserialize(&decode_hex(RFC_REGISTRATION_REQUEST))?,
            &credential_identifier,
        )?;
        assert_eq!(
            registration_response.message.serialize().as_slice(),
            decode_hex(RFC_REGISTRATION_RESPONSE)
        );

        let mut registration_finish_rng = CycleRng::new(decode_hex(RFC_ENVELOPE_NONCE));
        let registration_finish = registration.state.finish(
            &mut registration_finish_rng,
            &password,
            registration_response.message,
            ClientRegistrationFinishParameters::new(
                RfcIdentifiers {
                    client: client_identity.as_deref(),
                    server: server_identity.as_deref(),
                },
                None,
            ),
        )?;
        assert_eq!(
            registration_finish.message.serialize().as_slice(),
            decode_hex(vector.registration_upload)
        );
        let registration_export_key = Zeroizing::new(registration_finish.export_key);
        assert_eq!(
            registration_export_key.as_slice(),
            decode_hex(RFC_EXPORT_KEY)
        );
        let password_file =
            ServerRegistration::<Rfc9807IdentitySuite>::finish(registration_finish.message);

        let mut client_login_random = decode_hex(RFC_BLIND_LOGIN);
        // 依赖 crate 不带其内部 cfg(test)，VOPRF 会读取 64 字节再约简标量。
        client_login_random.extend_from_slice(&[0_u8; 32]);
        client_login_random.extend_from_slice(&decode_hex(RFC_CLIENT_KEYSHARE_SEED));
        client_login_random.extend_from_slice(&decode_hex(RFC_CLIENT_NONCE));
        let mut client_login_rng = CycleRng::new(client_login_random);
        let login = ClientLogin::<Rfc9807IdentitySuite>::start(&mut client_login_rng, &password)?;
        assert_eq!(login.message.serialize().as_slice(), decode_hex(RFC_KE1));

        let mut server_login_random = vec![0_u8; KEY_LENGTH];
        server_login_random.extend_from_slice(&decode_hex(RFC_MASKING_NONCE));
        server_login_random.extend_from_slice(&decode_hex(RFC_SERVER_KEYSHARE_SEED));
        server_login_random.extend_from_slice(&decode_hex(RFC_SERVER_NONCE));
        let mut server_login_rng = CycleRng::new(server_login_random);
        let server_login = ServerLogin::<Rfc9807IdentitySuite>::start(
            &mut server_login_rng,
            &server_setup,
            Some(password_file),
            RfcCredentialRequest::deserialize(&decode_hex(RFC_KE1))?,
            &credential_identifier,
            ServerLoginParameters {
                context: Some(&context),
                identifiers: RfcIdentifiers {
                    client: client_identity.as_deref(),
                    server: server_identity.as_deref(),
                },
            },
        )?;
        assert_eq!(
            server_login.message.serialize().as_slice(),
            decode_hex(vector.ke2)
        );

        let mut client_finish_rng = CycleRng::new(vec![0_u8; 32]);
        let client_finish = login.state.finish(
            &mut client_finish_rng,
            &password,
            server_login.message,
            ClientLoginFinishParameters::new(
                Some(&context),
                RfcIdentifiers {
                    client: client_identity.as_deref(),
                    server: server_identity.as_deref(),
                },
                None,
            ),
        )?;
        assert_eq!(
            client_finish.message.serialize().as_slice(),
            decode_hex(vector.ke3)
        );
        let client_session_key = Zeroizing::new(client_finish.session_key);
        let login_export_key = Zeroizing::new(client_finish.export_key);
        assert_eq!(
            client_session_key.as_slice(),
            decode_hex(vector.session_key)
        );
        assert_eq!(login_export_key.as_slice(), decode_hex(RFC_EXPORT_KEY));

        let server_finish = server_login.state.finish(
            client_finish.message,
            ServerLoginParameters {
                context: Some(&context),
                identifiers: RfcIdentifiers {
                    client: client_identity.as_deref(),
                    server: server_identity.as_deref(),
                },
            },
        )?;
        let server_session_key = Zeroizing::new(server_finish.session_key);
        assert_eq!(server_session_key.as_slice(), client_session_key.as_slice());
        Ok(())
    }

    #[test]
    fn rfc9807_official_ristretto_real_vectors_match_byte_for_byte() {
        run_rfc_real_vector(&RFC_REAL_VECTOR_1).expect("RFC 9807 真实向量 1 必须匹配");
        run_rfc_real_vector(&RFC_REAL_VECTOR_2).expect("RFC 9807 真实向量 2 必须匹配");
    }

    #[test]
    fn rfc9807_official_ristretto_fake_vector_matches_byte_for_byte() {
        const OPRF_SEED: &str = "
            743fc168d1f826ad43738933e5adb23da6fb95f95a1b069f0daa0522d0a78b61
            7f701fc6aa46d3e7981e70de7765dfcd6b1e13e3369a582eb8dc456b10aa53b0
        ";
        const SERVER_PRIVATE_KEY: &str = "
            c788585ae8b5ba2942b693b849be0c0426384e41977c18d2e81fbe30fd7c9f06
        ";
        const CLIENT_PUBLIC_KEY: &str = "
            84f43f9492e19c22d8bdaa4447cc3d4db1cdb5427a9f852c4707921212c36251
        ";
        const MASKING_KEY: &str = "
            39ebd51f0e39a07a1c2d2431995b0399bca9996c5d10014d6ebab4453dc10ce5
            cef38ed3df6e56bfff40c2d8dd4671c2b4cf63c3d54860f31fe40220d690bb71
        ";
        const MASKING_NONCE: &str = "
            9c035896a043e70f897d87180c543e7a063b83c1bb728fbd189c619e27b6e5a6
        ";
        const SERVER_KEYSHARE_SEED: &str = "
            360b0937f47d45f6123a4d8f0d0c0814b6120d840ebb8bc5b4f6b62df07f78c2
        ";
        const SERVER_NONCE: &str = "
            1e10f6eeab2a7a420bf09da9b27a4639645622c46358de9cf7ae813055ae2d12
        ";
        const KE1: &str = "
            b0a26dcaca2230b8f5e4b1bcab9c84b586140221bb8b2848486874b0be448905
            42d4e61ed3f8d64cdd3b9d153343eca15b9b0d5e388232793c6376bd2d9cfd0a
            b641d7f20a245a09f1d4dbb6e301661af7f352beb0791d055e48d3645232f77f
        ";
        const KE2: &str = "
            928f79ad8df21963e91411b9f55165ba833dea918f441db967cdc09521d22925
            9c035896a043e70f897d87180c543e7a063b83c1bb728fbd189c619e27b6e5a632b5a
            b1bff96636144faa4f9f9afaac75dd88ea99cf5175902ae3f3b2195693f165f11929b
            a510a5978e64dcdabecbd7ee1e4380ce270e58fea58e6462d92964a1aaef72698bca1
            c673baeb04cc2bf7de5f3c2f5553464552d3a0f7698a9ca7f9c5e70c6cb1f706b2f17
            5ab9d04bbd13926e816b6811a50b4aafa9799d5ed7971e10f6eeab2a7a420bf09da9b
            27a4639645622c46358de9cf7ae813055ae2d1298251c5ba55f6b0b2d58d9ff0c88fe
            4176484be62a96db6e2a8c4d431bd1bf27fe6c1d0537603835217d42ebf7b25819827
            32e74892fd28211b31ed33863f0beaf75ba6f59474c0aaf9d78a60a9b2f4cd24d7ab5
            4131b3c8efa192df6b72db4c
        ";

        let setup_bytes = [
            decode_hex(OPRF_SEED),
            decode_hex(SERVER_PRIVATE_KEY),
            decode_hex(CLIENT_PUBLIC_KEY),
        ]
        .concat();
        let setup = RfcServerSetup::<Rfc9807IdentitySuite>::deserialize(&setup_bytes)
            .expect("RFC 假向量 setup 必须有效");
        let context = decode_hex(RFC_CONTEXT);
        let client_identity = decode_hex("616c696365");
        let server_identity = decode_hex("626f62");
        let credential_identifier = decode_hex(RFC_CREDENTIAL_IDENTIFIER);

        let mut random = decode_hex(MASKING_KEY);
        random.extend_from_slice(&decode_hex(MASKING_NONCE));
        random.extend_from_slice(&decode_hex(SERVER_KEYSHARE_SEED));
        random.extend_from_slice(&decode_hex(SERVER_NONCE));
        let mut rng = CycleRng::new(random);
        let response = ServerLogin::<Rfc9807IdentitySuite>::start(
            &mut rng,
            &setup,
            None,
            RfcCredentialRequest::deserialize(&decode_hex(KE1)).expect("RFC 假向量 KE1 必须有效"),
            &credential_identifier,
            ServerLoginParameters {
                context: Some(&context),
                identifiers: RfcIdentifiers {
                    client: Some(&client_identity),
                    server: Some(&server_identity),
                },
            },
        )
        .expect("未知账户必须生成 RFC 假响应");
        assert_eq!(response.message.serialize().as_slice(), decode_hex(KE2));
    }
}
