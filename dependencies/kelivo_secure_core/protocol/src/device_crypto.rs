//! 设备身份与账户根密钥信封的唯一 v1 线格式。
//!
//! KDPF 使用固定 224 字节签名消息；KAEK 使用固定 336 字节自包含信封。
//! 两种格式都把算法、身份和用途写入被认证数据，避免调用方自行拼接上下文。

use std::{convert::Infallible, fmt};

use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use hpke::{
    Deserializable, Kem as HpkeKemTrait, OpModeR, OpModeS, Serializable,
    aead::{AeadTag, ChaCha20Poly1305 as HpkeAead},
    inout::InOutBuf,
    kdf::HkdfSha256 as HpkeKdf,
    kem::X25519HkdfSha256 as HpkeKem,
    setup_receiver, setup_sender_with_rng,
};
use rand::{CryptoRng, RngCore};
use sha2_device::{Digest, Sha256};
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

const DEVICE_PROOF_MAGIC: [u8; 4] = *b"KDPF";
pub const DEVICE_PROOF_VERSION: u16 = 1;
const DEVICE_PROOF_FLAGS: u8 = 0;
const DEVICE_PROOF_HEADER_LENGTH: usize = 8;
const UUID_LENGTH: usize = 16;
pub const DEVICE_PUBLIC_KEY_LENGTH: usize = 32;
pub const DEVICE_PRIVATE_KEY_LENGTH: usize = 32;
pub const SHA256_DIGEST_LENGTH: usize = 32;
pub const DEVICE_PROOF_CHALLENGE_LENGTH: usize = 32;
pub const DEVICE_PROOF_MESSAGE_LENGTH: usize = 224;
pub const DEVICE_PROOF_SIGNATURE_LENGTH: usize = 64;
const ARK_ENVELOPE_MAGIC: [u8; 4] = *b"KAEK";
pub const ARK_ENVELOPE_VERSION: u16 = 1;
/// KAEK 套件 1 固定映射 RFC 9180：KEM 0x0020、KDF 0x0001、AEAD 0x0003。
pub const ARK_ENVELOPE_SUITE_ID: u16 = 1;
const ARK_ENVELOPE_FLAGS: u16 = 0;
const ARK_ENVELOPE_RESERVED: u16 = 0;
const ARK_ENVELOPE_HEADER_LENGTH: usize = 12;
pub const ACCOUNT_ROOT_KEY_LENGTH: usize = 32;
pub const ARK_HPKE_ENCAPSULATED_KEY_LENGTH: usize = 32;
pub const ARK_HPKE_CIPHERTEXT_LENGTH: usize = ACCOUNT_ROOT_KEY_LENGTH + 16;
pub const ARK_ENVELOPE_LENGTH: usize = 336;
const ARK_ENVELOPE_SIGNATURE_LENGTH: usize = 64;

const PROOF_ATTEMPT_OFFSET: usize = DEVICE_PROOF_HEADER_LENGTH;
const PROOF_ACCOUNT_OFFSET: usize = PROOF_ATTEMPT_OFFSET + UUID_LENGTH;
const PROOF_DEVICE_OFFSET: usize = PROOF_ACCOUNT_OFFSET + UUID_LENGTH;
const PROOF_EXPIRES_OFFSET: usize = PROOF_DEVICE_OFFSET + UUID_LENGTH;
const PROOF_CHALLENGE_OFFSET: usize = PROOF_EXPIRES_OFFSET + size_of::<u64>();
const PROOF_SIGNING_KEY_OFFSET: usize = PROOF_CHALLENGE_OFFSET + DEVICE_PROOF_CHALLENGE_LENGTH;
const PROOF_KEY_AGREEMENT_OFFSET: usize = PROOF_SIGNING_KEY_OFFSET + DEVICE_PUBLIC_KEY_LENGTH;
const PROOF_OPAQUE_HASH_OFFSET: usize = PROOF_KEY_AGREEMENT_OFFSET + DEVICE_PUBLIC_KEY_LENGTH;
const PROOF_ENVELOPE_HASH_OFFSET: usize = PROOF_OPAQUE_HASH_OFFSET + SHA256_DIGEST_LENGTH;
const ARK_USER_OFFSET: usize = ARK_ENVELOPE_HEADER_LENGTH;
const ARK_ISSUER_DEVICE_OFFSET: usize = ARK_USER_OFFSET + UUID_LENGTH;
const ARK_TARGET_DEVICE_OFFSET: usize = ARK_ISSUER_DEVICE_OFFSET + UUID_LENGTH;
const ARK_EPOCH_OFFSET: usize = ARK_TARGET_DEVICE_OFFSET + UUID_LENGTH;
const ARK_ISSUER_SIGNING_KEY_OFFSET: usize = ARK_EPOCH_OFFSET + size_of::<u32>();
const ARK_ISSUER_KEY_AGREEMENT_OFFSET: usize =
    ARK_ISSUER_SIGNING_KEY_OFFSET + DEVICE_PUBLIC_KEY_LENGTH;
const ARK_TARGET_SIGNING_KEY_OFFSET: usize =
    ARK_ISSUER_KEY_AGREEMENT_OFFSET + DEVICE_PUBLIC_KEY_LENGTH;
const ARK_TARGET_KEY_AGREEMENT_OFFSET: usize =
    ARK_TARGET_SIGNING_KEY_OFFSET + DEVICE_PUBLIC_KEY_LENGTH;
const ARK_ENCAPSULATED_KEY_OFFSET: usize =
    ARK_TARGET_KEY_AGREEMENT_OFFSET + DEVICE_PUBLIC_KEY_LENGTH;
const ARK_CIPHERTEXT_OFFSET: usize = ARK_ENCAPSULATED_KEY_OFFSET + ARK_HPKE_ENCAPSULATED_KEY_LENGTH;
const ARK_SIGNATURE_OFFSET: usize = ARK_CIPHERTEXT_OFFSET + ARK_HPKE_CIPHERTEXT_LENGTH;

const _: () = {
    assert!(PROOF_ENVELOPE_HASH_OFFSET + SHA256_DIGEST_LENGTH == DEVICE_PROOF_MESSAGE_LENGTH);
    assert!(ARK_ENCAPSULATED_KEY_OFFSET == 192);
    assert!(ARK_SIGNATURE_OFFSET + ARK_ENVELOPE_SIGNATURE_LENGTH == ARK_ENVELOPE_LENGTH);
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DeviceCryptoError {
    InvalidUuidV4,
    InvalidExpiry,
    InvalidSigningPublicKey,
    InvalidKeyAgreementPublicKey,
    InvalidKeyAgreementPrivateKey,
    SigningKeyMismatch,
    InvalidDeviceProofMagic,
    UnsupportedDeviceProofVersion(u16),
    UnsupportedDeviceProofKind(u8),
    UnsupportedDeviceProofFlags(u8),
    InvalidDeviceProofLength { expected: usize, actual: usize },
    InvalidDeviceProofSignatureLength { expected: usize, actual: usize },
    DeviceProofBindingMismatch,
    DeviceProofSignatureInvalid,
    InvalidKeyEpoch,
    InvalidArkEnvelopeMagic,
    UnsupportedArkEnvelopeVersion(u16),
    UnsupportedArkEnvelopeSuite(u16),
    UnsupportedArkEnvelopeFlags(u16),
    UnsupportedArkEnvelopeReserved(u16),
    InvalidArkEnvelopeLength { expected: usize, actual: usize },
    ArkEnvelopeBindingMismatch,
    ArkEnvelopeSignatureInvalid,
    KeyAgreementKeyMismatch,
    ArkEnvelopeSealFailed,
    ArkEnvelopeOpenFailed,
}

impl fmt::Display for DeviceCryptoError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidUuidV4 => formatter.write_str("设备密码学标识不是 RFC 4122 UUIDv4"),
            Self::InvalidExpiry => formatter.write_str("设备密码学过期时间无效"),
            Self::InvalidSigningPublicKey => formatter.write_str("Ed25519 公钥无效"),
            Self::InvalidKeyAgreementPublicKey => formatter.write_str("X25519 公钥无效"),
            Self::InvalidKeyAgreementPrivateKey => formatter.write_str("X25519 私钥无效"),
            Self::SigningKeyMismatch => {
                formatter.write_str("Ed25519 私钥与设备证明绑定的公钥不匹配")
            }
            Self::InvalidDeviceProofMagic => formatter.write_str("设备证明魔数无效"),
            Self::UnsupportedDeviceProofVersion(version) => {
                write!(formatter, "不支持的设备证明版本：{version}")
            }
            Self::UnsupportedDeviceProofKind(kind) => {
                write!(formatter, "不支持的设备证明类型：{kind}")
            }
            Self::UnsupportedDeviceProofFlags(flags) => {
                write!(formatter, "设备证明包含不支持的标志：{flags}")
            }
            Self::InvalidDeviceProofLength { expected, actual } => write!(
                formatter,
                "设备证明长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::InvalidDeviceProofSignatureLength { expected, actual } => write!(
                formatter,
                "设备证明签名长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::DeviceProofBindingMismatch => {
                formatter.write_str("设备证明与服务端预期字段不匹配")
            }
            Self::DeviceProofSignatureInvalid => formatter.write_str("设备证明签名无效"),
            Self::InvalidKeyEpoch => formatter.write_str("ARK 密钥代次无效"),
            Self::InvalidArkEnvelopeMagic => formatter.write_str("ARK 信封魔数无效"),
            Self::UnsupportedArkEnvelopeVersion(version) => {
                write!(formatter, "不支持的 ARK 信封版本：{version}")
            }
            Self::UnsupportedArkEnvelopeSuite(suite) => {
                write!(formatter, "不支持的 ARK 信封密码套件：{suite}")
            }
            Self::UnsupportedArkEnvelopeFlags(flags) => {
                write!(formatter, "ARK 信封包含不支持的标志：{flags}")
            }
            Self::UnsupportedArkEnvelopeReserved(reserved) => {
                write!(formatter, "ARK 信封保留字段必须为零，实际 {reserved}")
            }
            Self::InvalidArkEnvelopeLength { expected, actual } => write!(
                formatter,
                "ARK 信封长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::ArkEnvelopeBindingMismatch => {
                formatter.write_str("ARK 信封与预期账户或设备绑定不匹配")
            }
            Self::ArkEnvelopeSignatureInvalid => formatter.write_str("ARK 信封签名无效"),
            Self::KeyAgreementKeyMismatch => formatter.write_str("X25519 私钥与目标设备公钥不匹配"),
            Self::ArkEnvelopeSealFailed => formatter.write_str("ARK 信封 HPKE 密封失败"),
            Self::ArkEnvelopeOpenFailed => formatter.write_str("ARK 信封 HPKE 打开失败"),
        }
    }
}

impl std::error::Error for DeviceCryptoError {}

fn is_uuid_v4(bytes: &[u8; UUID_LENGTH]) -> bool {
    bytes[6] & 0xf0 == 0x40 && bytes[8] & 0xc0 == 0x80
}

macro_rules! define_uuid_v4 {
    ($name:ident) => {
        #[derive(Clone, Copy, Debug, Eq, PartialEq)]
        pub struct $name([u8; UUID_LENGTH]);

        impl $name {
            pub fn new(bytes: [u8; UUID_LENGTH]) -> Result<Self, DeviceCryptoError> {
                if !is_uuid_v4(&bytes) {
                    return Err(DeviceCryptoError::InvalidUuidV4);
                }
                Ok(Self(bytes))
            }

            pub fn as_bytes(&self) -> &[u8; UUID_LENGTH] {
                &self.0
            }
        }
    };
}

define_uuid_v4!(OpaqueAttemptId);
define_uuid_v4!(AccountBindingId);
define_uuid_v4!(UserId);
define_uuid_v4!(DeviceId);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct DeviceProofChallenge([u8; DEVICE_PROOF_CHALLENGE_LENGTH]);

impl DeviceProofChallenge {
    pub const fn from_bytes(bytes: [u8; DEVICE_PROOF_CHALLENGE_LENGTH]) -> Self {
        Self(bytes)
    }

    pub const fn as_bytes(&self) -> &[u8; DEVICE_PROOF_CHALLENGE_LENGTH] {
        &self.0
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Sha256Digest([u8; SHA256_DIGEST_LENGTH]);

impl Sha256Digest {
    pub fn of(bytes: &[u8]) -> Self {
        Self(Sha256::digest(bytes).into())
    }

    pub const fn from_bytes(bytes: [u8; SHA256_DIGEST_LENGTH]) -> Self {
        Self(bytes)
    }

    pub const fn as_bytes(&self) -> &[u8; SHA256_DIGEST_LENGTH] {
        &self.0
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct DeviceSigningPublicKey([u8; DEVICE_PUBLIC_KEY_LENGTH]);

impl DeviceSigningPublicKey {
    pub fn from_bytes(bytes: [u8; DEVICE_PUBLIC_KEY_LENGTH]) -> Result<Self, DeviceCryptoError> {
        let public_key = VerifyingKey::from_bytes(&bytes)
            .map_err(|_| DeviceCryptoError::InvalidSigningPublicKey)?;
        if public_key.is_weak() {
            return Err(DeviceCryptoError::InvalidSigningPublicKey);
        }
        Ok(Self(bytes))
    }

    pub const fn as_bytes(&self) -> &[u8; DEVICE_PUBLIC_KEY_LENGTH] {
        &self.0
    }

    fn verifying_key(&self) -> Result<VerifyingKey, DeviceCryptoError> {
        VerifyingKey::from_bytes(&self.0).map_err(|_| DeviceCryptoError::InvalidSigningPublicKey)
    }
}

/// Ed25519 私钥种子只允许导入和使用，不提供读回入口。
///
/// ```compile_fail
/// use kelivo_secure_core_protocol::device_crypto::DeviceSigningPrivateKey;
///
/// let key = DeviceSigningPrivateKey::from_seed([7; 32]);
/// let DeviceSigningPrivateKey(raw) = key;
/// let _ = raw;
/// ```
pub struct DeviceSigningPrivateKey([u8; DEVICE_PRIVATE_KEY_LENGTH]);

impl DeviceSigningPrivateKey {
    pub const fn from_seed(seed: [u8; DEVICE_PRIVATE_KEY_LENGTH]) -> Self {
        Self(seed)
    }

    pub fn public_key(&self) -> DeviceSigningPublicKey {
        DeviceSigningPublicKey(SigningKey::from_bytes(&self.0).verifying_key().to_bytes())
    }

    fn signing_key(&self) -> SigningKey {
        SigningKey::from_bytes(&self.0)
    }
}

impl Zeroize for DeviceSigningPrivateKey {
    fn zeroize(&mut self) {
        self.0.zeroize();
    }
}

impl ZeroizeOnDrop for DeviceSigningPrivateKey {}

impl Drop for DeviceSigningPrivateKey {
    fn drop(&mut self) {
        self.zeroize();
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct DeviceKeyAgreementPublicKey([u8; DEVICE_PUBLIC_KEY_LENGTH]);

impl DeviceKeyAgreementPublicKey {
    pub fn from_bytes(bytes: [u8; DEVICE_PUBLIC_KEY_LENGTH]) -> Result<Self, DeviceCryptoError> {
        if bytes == [0; DEVICE_PUBLIC_KEY_LENGTH] {
            return Err(DeviceCryptoError::InvalidKeyAgreementPublicKey);
        }
        let public_key =
            <<HpkeKem as HpkeKemTrait>::PublicKey as Deserializable>::from_bytes(&bytes)
                .map_err(|_| DeviceCryptoError::InvalidKeyAgreementPublicKey)?;
        // X25519 编码几乎都能反序列化；固定临时标量只用于触发 RFC 7748 全零共享值检查，
        // 不会生成信封或成为任何长期密钥材料。
        HpkeKem::encap_with_rng(&public_key, None, &mut PublicKeyValidationRng)
            .map_err(|_| DeviceCryptoError::InvalidKeyAgreementPublicKey)?;
        Ok(Self(bytes))
    }

    pub const fn as_bytes(&self) -> &[u8; DEVICE_PUBLIC_KEY_LENGTH] {
        &self.0
    }

    fn hpke_public_key(&self) -> Result<<HpkeKem as HpkeKemTrait>::PublicKey, DeviceCryptoError> {
        <<HpkeKem as HpkeKemTrait>::PublicKey as Deserializable>::from_bytes(&self.0)
            .map_err(|_| DeviceCryptoError::InvalidKeyAgreementPublicKey)
    }
}

/// X25519 私钥只允许导入和执行密钥协商，不提供读回入口。
///
/// ```compile_fail
/// use kelivo_secure_core_protocol::device_crypto::DeviceKeyAgreementPrivateKey;
///
/// let key = DeviceKeyAgreementPrivateKey::from_bytes([7; 32]).unwrap();
/// let DeviceKeyAgreementPrivateKey(raw) = key;
/// let _ = raw;
/// ```
pub struct DeviceKeyAgreementPrivateKey([u8; DEVICE_PRIVATE_KEY_LENGTH]);

impl DeviceKeyAgreementPrivateKey {
    pub fn from_bytes(bytes: [u8; DEVICE_PRIVATE_KEY_LENGTH]) -> Result<Self, DeviceCryptoError> {
        <<HpkeKem as HpkeKemTrait>::PrivateKey as Deserializable>::from_bytes(&bytes)
            .map_err(|_| DeviceCryptoError::InvalidKeyAgreementPrivateKey)?;
        Ok(Self(bytes))
    }

    pub fn public_key(&self) -> DeviceKeyAgreementPublicKey {
        let private_key = self.hpke_private_key().expect("构造函数已验证 X25519 私钥");
        let public_key = HpkeKem::sk_to_pk(&private_key);
        let bytes: [u8; DEVICE_PUBLIC_KEY_LENGTH] = public_key.to_bytes().into();
        DeviceKeyAgreementPublicKey(bytes)
    }

    fn hpke_private_key(&self) -> Result<<HpkeKem as HpkeKemTrait>::PrivateKey, DeviceCryptoError> {
        <<HpkeKem as HpkeKemTrait>::PrivateKey as Deserializable>::from_bytes(&self.0)
            .map_err(|_| DeviceCryptoError::InvalidKeyAgreementPrivateKey)
    }
}

impl Zeroize for DeviceKeyAgreementPrivateKey {
    fn zeroize(&mut self) {
        self.0.zeroize();
    }
}

impl ZeroizeOnDrop for DeviceKeyAgreementPrivateKey {}

impl Drop for DeviceKeyAgreementPrivateKey {
    fn drop(&mut self) {
        self.zeroize();
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum DeviceProofKind {
    RegistrationFinish = 1,
    LoginFinish = 2,
}

impl DeviceProofKind {
    fn from_u8(value: u8) -> Result<Self, DeviceCryptoError> {
        match value {
            1 => Ok(Self::RegistrationFinish),
            2 => Ok(Self::LoginFinish),
            _ => Err(DeviceCryptoError::UnsupportedDeviceProofKind(value)),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct DeviceProofFields {
    pub kind: DeviceProofKind,
    /// 服务端一次性 OPAQUE attempt UUIDv4。
    pub attempt_id: OpaqueAttemptId,
    /// OPAQUE 使用的 16 字节 credential/account binding UUIDv4。
    pub account_binding: AccountBindingId,
    pub device_id: DeviceId,
    /// 服务端签发的毫秒 Unix 时间戳；零值永远无效。
    pub expires_at_ms: u64,
    /// 服务端为本次 finish 签发的 32 字节随机挑战。
    pub challenge: DeviceProofChallenge,
    pub signing_public_key: DeviceSigningPublicKey,
    pub key_agreement_public_key: DeviceKeyAgreementPublicKey,
    /// 对本次 RegistrationUpload 或 CredentialFinalization 完整线格式求 SHA-256。
    pub opaque_finish_hash: Sha256Digest,
    /// 对同请求携带的 KAEK 信封求 SHA-256；没有信封时使用 SHA-256(empty)。
    pub envelope_hash: Sha256Digest,
}

pub struct DeviceProofMessage([u8; DEVICE_PROOF_MESSAGE_LENGTH]);

impl DeviceProofMessage {
    pub fn new(fields: DeviceProofFields) -> Result<Self, DeviceCryptoError> {
        if fields.expires_at_ms == 0 {
            return Err(DeviceCryptoError::InvalidExpiry);
        }

        let mut bytes = [0_u8; DEVICE_PROOF_MESSAGE_LENGTH];
        bytes[..4].copy_from_slice(&DEVICE_PROOF_MAGIC);
        bytes[4..6].copy_from_slice(&DEVICE_PROOF_VERSION.to_be_bytes());
        bytes[6] = fields.kind as u8;
        bytes[7] = DEVICE_PROOF_FLAGS;
        bytes[PROOF_ATTEMPT_OFFSET..PROOF_ACCOUNT_OFFSET]
            .copy_from_slice(fields.attempt_id.as_bytes());
        bytes[PROOF_ACCOUNT_OFFSET..PROOF_DEVICE_OFFSET]
            .copy_from_slice(fields.account_binding.as_bytes());
        bytes[PROOF_DEVICE_OFFSET..PROOF_EXPIRES_OFFSET]
            .copy_from_slice(fields.device_id.as_bytes());
        bytes[PROOF_EXPIRES_OFFSET..PROOF_CHALLENGE_OFFSET]
            .copy_from_slice(&fields.expires_at_ms.to_be_bytes());
        bytes[PROOF_CHALLENGE_OFFSET..PROOF_SIGNING_KEY_OFFSET]
            .copy_from_slice(fields.challenge.as_bytes());
        bytes[PROOF_SIGNING_KEY_OFFSET..PROOF_KEY_AGREEMENT_OFFSET]
            .copy_from_slice(fields.signing_public_key.as_bytes());
        bytes[PROOF_KEY_AGREEMENT_OFFSET..PROOF_OPAQUE_HASH_OFFSET]
            .copy_from_slice(fields.key_agreement_public_key.as_bytes());
        bytes[PROOF_OPAQUE_HASH_OFFSET..PROOF_ENVELOPE_HASH_OFFSET]
            .copy_from_slice(fields.opaque_finish_hash.as_bytes());
        bytes[PROOF_ENVELOPE_HASH_OFFSET..].copy_from_slice(fields.envelope_hash.as_bytes());
        Ok(Self(bytes))
    }

    pub fn from_bytes(bytes: &[u8]) -> Result<Self, DeviceCryptoError> {
        if bytes.len() != DEVICE_PROOF_MESSAGE_LENGTH {
            return Err(DeviceCryptoError::InvalidDeviceProofLength {
                expected: DEVICE_PROOF_MESSAGE_LENGTH,
                actual: bytes.len(),
            });
        }
        if bytes[..4] != DEVICE_PROOF_MAGIC {
            return Err(DeviceCryptoError::InvalidDeviceProofMagic);
        }
        let version = u16::from_be_bytes([bytes[4], bytes[5]]);
        if version != DEVICE_PROOF_VERSION {
            return Err(DeviceCryptoError::UnsupportedDeviceProofVersion(version));
        }
        DeviceProofKind::from_u8(bytes[6])?;
        if bytes[7] != DEVICE_PROOF_FLAGS {
            return Err(DeviceCryptoError::UnsupportedDeviceProofFlags(bytes[7]));
        }

        OpaqueAttemptId::new(copy_array(
            &bytes[PROOF_ATTEMPT_OFFSET..PROOF_ACCOUNT_OFFSET],
        ))?;
        AccountBindingId::new(copy_array(
            &bytes[PROOF_ACCOUNT_OFFSET..PROOF_DEVICE_OFFSET],
        ))?;
        DeviceId::new(copy_array(
            &bytes[PROOF_DEVICE_OFFSET..PROOF_EXPIRES_OFFSET],
        ))?;
        let expires_at_ms = u64::from_be_bytes(copy_array(
            &bytes[PROOF_EXPIRES_OFFSET..PROOF_CHALLENGE_OFFSET],
        ));
        if expires_at_ms == 0 {
            return Err(DeviceCryptoError::InvalidExpiry);
        }
        DeviceSigningPublicKey::from_bytes(copy_array(
            &bytes[PROOF_SIGNING_KEY_OFFSET..PROOF_KEY_AGREEMENT_OFFSET],
        ))?;
        DeviceKeyAgreementPublicKey::from_bytes(copy_array(
            &bytes[PROOF_KEY_AGREEMENT_OFFSET..PROOF_OPAQUE_HASH_OFFSET],
        ))?;

        Ok(Self(copy_array(bytes)))
    }

    pub const fn as_bytes(&self) -> &[u8; DEVICE_PROOF_MESSAGE_LENGTH] {
        &self.0
    }

    pub fn sign(
        &self,
        signing_key: &DeviceSigningPrivateKey,
    ) -> Result<DeviceProofSignature, DeviceCryptoError> {
        if signing_key.public_key().as_bytes()
            != &self.0[PROOF_SIGNING_KEY_OFFSET..PROOF_KEY_AGREEMENT_OFFSET]
        {
            return Err(DeviceCryptoError::SigningKeyMismatch);
        }
        Ok(DeviceProofSignature(
            signing_key.signing_key().sign(&self.0).to_bytes(),
        ))
    }

    /// `expected_fields` 必须全部来自服务端已冻结的 attempt、请求摘要与可信设备记录，
    /// 不能从客户端提交的 224 字节消息反向提取后再作为预期值。
    pub fn verify_expected(
        &self,
        expected_fields: DeviceProofFields,
        signature: &DeviceProofSignature,
    ) -> Result<(), DeviceCryptoError> {
        let expected_message = Self::new(expected_fields)?;
        if self.0 != expected_message.0 {
            return Err(DeviceCryptoError::DeviceProofBindingMismatch);
        }
        expected_fields
            .signing_public_key
            .verifying_key()?
            .verify_strict(&self.0, &Signature::from_bytes(&signature.0))
            .map_err(|_| DeviceCryptoError::DeviceProofSignatureInvalid)
    }
}

pub struct DeviceProofSignature([u8; DEVICE_PROOF_SIGNATURE_LENGTH]);

impl DeviceProofSignature {
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, DeviceCryptoError> {
        if bytes.len() != DEVICE_PROOF_SIGNATURE_LENGTH {
            return Err(DeviceCryptoError::InvalidDeviceProofSignatureLength {
                expected: DEVICE_PROOF_SIGNATURE_LENGTH,
                actual: bytes.len(),
            });
        }
        Ok(Self(copy_array(bytes)))
    }

    pub const fn as_bytes(&self) -> &[u8; DEVICE_PROOF_SIGNATURE_LENGTH] {
        &self.0
    }
}

pub struct AccountRootKey([u8; ACCOUNT_ROOT_KEY_LENGTH]);

impl AccountRootKey {
    pub const fn from_bytes(bytes: [u8; ACCOUNT_ROOT_KEY_LENGTH]) -> Self {
        Self(bytes)
    }

    pub const fn as_bytes(&self) -> &[u8; ACCOUNT_ROOT_KEY_LENGTH] {
        &self.0
    }
}

impl Zeroize for AccountRootKey {
    fn zeroize(&mut self) {
        self.0.zeroize();
    }
}

impl ZeroizeOnDrop for AccountRootKey {}

impl Drop for AccountRootKey {
    fn drop(&mut self) {
        self.zeroize();
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ArkEnvelopeBinding {
    pub user_id: UserId,
    pub issuer_device_id: DeviceId,
    pub target_device_id: DeviceId,
    /// ARK 轮换代次从 1 开始，零值保留为无效状态。
    pub key_epoch: u32,
    pub issuer_signing_public_key: DeviceSigningPublicKey,
    pub issuer_key_agreement_public_key: DeviceKeyAgreementPublicKey,
    pub target_signing_public_key: DeviceSigningPublicKey,
    pub target_key_agreement_public_key: DeviceKeyAgreementPublicKey,
}

pub struct ArkEnvelope([u8; ARK_ENVELOPE_LENGTH]);

impl ArkEnvelope {
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, DeviceCryptoError> {
        if bytes.len() != ARK_ENVELOPE_LENGTH {
            return Err(DeviceCryptoError::InvalidArkEnvelopeLength {
                expected: ARK_ENVELOPE_LENGTH,
                actual: bytes.len(),
            });
        }
        if bytes[..4] != ARK_ENVELOPE_MAGIC {
            return Err(DeviceCryptoError::InvalidArkEnvelopeMagic);
        }

        let version = u16::from_be_bytes(copy_array(&bytes[4..6]));
        if version != ARK_ENVELOPE_VERSION {
            return Err(DeviceCryptoError::UnsupportedArkEnvelopeVersion(version));
        }
        let suite = u16::from_be_bytes(copy_array(&bytes[6..8]));
        if suite != ARK_ENVELOPE_SUITE_ID {
            return Err(DeviceCryptoError::UnsupportedArkEnvelopeSuite(suite));
        }
        let flags = u16::from_be_bytes(copy_array(&bytes[8..10]));
        if flags != ARK_ENVELOPE_FLAGS {
            return Err(DeviceCryptoError::UnsupportedArkEnvelopeFlags(flags));
        }
        let reserved = u16::from_be_bytes(copy_array(&bytes[10..12]));
        if reserved != ARK_ENVELOPE_RESERVED {
            return Err(DeviceCryptoError::UnsupportedArkEnvelopeReserved(reserved));
        }

        UserId::new(copy_array(
            &bytes[ARK_USER_OFFSET..ARK_ISSUER_DEVICE_OFFSET],
        ))?;
        DeviceId::new(copy_array(
            &bytes[ARK_ISSUER_DEVICE_OFFSET..ARK_TARGET_DEVICE_OFFSET],
        ))?;
        DeviceId::new(copy_array(
            &bytes[ARK_TARGET_DEVICE_OFFSET..ARK_EPOCH_OFFSET],
        ))?;
        let key_epoch = u32::from_be_bytes(copy_array(
            &bytes[ARK_EPOCH_OFFSET..ARK_ISSUER_SIGNING_KEY_OFFSET],
        ));
        if key_epoch == 0 {
            return Err(DeviceCryptoError::InvalidKeyEpoch);
        }
        DeviceSigningPublicKey::from_bytes(copy_array(
            &bytes[ARK_ISSUER_SIGNING_KEY_OFFSET..ARK_ISSUER_KEY_AGREEMENT_OFFSET],
        ))?;
        DeviceKeyAgreementPublicKey::from_bytes(copy_array(
            &bytes[ARK_ISSUER_KEY_AGREEMENT_OFFSET..ARK_TARGET_SIGNING_KEY_OFFSET],
        ))?;
        DeviceSigningPublicKey::from_bytes(copy_array(
            &bytes[ARK_TARGET_SIGNING_KEY_OFFSET..ARK_TARGET_KEY_AGREEMENT_OFFSET],
        ))?;
        DeviceKeyAgreementPublicKey::from_bytes(copy_array(
            &bytes[ARK_TARGET_KEY_AGREEMENT_OFFSET..ARK_ENCAPSULATED_KEY_OFFSET],
        ))?;
        <<HpkeKem as HpkeKemTrait>::EncappedKey as Deserializable>::from_bytes(
            &bytes[ARK_ENCAPSULATED_KEY_OFFSET..ARK_CIPHERTEXT_OFFSET],
        )
        .map_err(|_| DeviceCryptoError::ArkEnvelopeOpenFailed)?;

        Ok(Self(copy_array(bytes)))
    }

    pub const fn as_bytes(&self) -> &[u8; ARK_ENVELOPE_LENGTH] {
        &self.0
    }
}

pub fn seal_ark_envelope<R>(
    rng: &mut R,
    ark: &AccountRootKey,
    binding: ArkEnvelopeBinding,
    issuer_signing_key: &DeviceSigningPrivateKey,
) -> Result<ArkEnvelope, DeviceCryptoError>
where
    R: CryptoRng + RngCore,
{
    let binding_bytes = encode_ark_envelope_binding(binding)?;
    if issuer_signing_key.public_key() != binding.issuer_signing_public_key {
        return Err(DeviceCryptoError::SigningKeyMismatch);
    }

    let target_public_key = binding.target_key_agreement_public_key.hpke_public_key()?;
    let mut rng = HpkeRngAdapter(rng);
    let (encapsulated_key, mut sender_context) =
        setup_sender_with_rng::<HpkeAead, HpkeKdf, HpkeKem>(
            &OpModeS::Base,
            &target_public_key,
            &binding_bytes,
            &mut rng,
        )
        .map_err(|_| DeviceCryptoError::ArkEnvelopeSealFailed)?;
    let mut encrypted_ark = Zeroizing::new(*ark.as_bytes());
    let tag = sender_context
        .seal_inout_detached(InOutBuf::from(encrypted_ark.as_mut_slice()), &binding_bytes)
        .map_err(|_| DeviceCryptoError::ArkEnvelopeSealFailed)?;

    let mut bytes = [0_u8; ARK_ENVELOPE_LENGTH];
    bytes[..ARK_ENCAPSULATED_KEY_OFFSET].copy_from_slice(&binding_bytes);
    bytes[ARK_ENCAPSULATED_KEY_OFFSET..ARK_CIPHERTEXT_OFFSET]
        .copy_from_slice(encapsulated_key.to_bytes().as_slice());
    let ark_ciphertext_end = ARK_CIPHERTEXT_OFFSET + ACCOUNT_ROOT_KEY_LENGTH;
    bytes[ARK_CIPHERTEXT_OFFSET..ark_ciphertext_end].copy_from_slice(encrypted_ark.as_slice());
    bytes[ark_ciphertext_end..ARK_SIGNATURE_OFFSET].copy_from_slice(tag.to_bytes().as_slice());
    let signature = issuer_signing_key
        .signing_key()
        .sign(&bytes[..ARK_SIGNATURE_OFFSET])
        .to_bytes();
    bytes[ARK_SIGNATURE_OFFSET..].copy_from_slice(&signature);
    Ok(ArkEnvelope(bytes))
}

/// 预期绑定必须来自可信账户与设备记录；信封内自带的 issuer 公钥不是信任根。
pub fn verify_ark_envelope(
    envelope: &ArkEnvelope,
    expected_binding: ArkEnvelopeBinding,
) -> Result<(), DeviceCryptoError> {
    let expected_binding_bytes = encode_ark_envelope_binding(expected_binding)?;
    if envelope.0[..ARK_ENCAPSULATED_KEY_OFFSET] != expected_binding_bytes {
        return Err(DeviceCryptoError::ArkEnvelopeBindingMismatch);
    }

    let signature = Signature::from_bytes(&copy_array(
        &envelope.0[ARK_SIGNATURE_OFFSET..ARK_ENVELOPE_LENGTH],
    ));
    expected_binding
        .issuer_signing_public_key
        .verifying_key()?
        .verify_strict(&envelope.0[..ARK_SIGNATURE_OFFSET], &signature)
        .map_err(|_| DeviceCryptoError::ArkEnvelopeSignatureInvalid)
}

pub fn open_ark_envelope(
    envelope: &ArkEnvelope,
    expected_binding: ArkEnvelopeBinding,
    target_private_key: &DeviceKeyAgreementPrivateKey,
) -> Result<AccountRootKey, DeviceCryptoError> {
    // 先确认可信签发设备，再接触目标设备私钥，避免把未认证密文送入解密路径。
    verify_ark_envelope(envelope, expected_binding)?;
    if target_private_key.public_key() != expected_binding.target_key_agreement_public_key {
        return Err(DeviceCryptoError::KeyAgreementKeyMismatch);
    }

    let target_private_key = target_private_key.hpke_private_key()?;
    let encapsulated_key = <<HpkeKem as HpkeKemTrait>::EncappedKey as Deserializable>::from_bytes(
        &envelope.0[ARK_ENCAPSULATED_KEY_OFFSET..ARK_CIPHERTEXT_OFFSET],
    )
    .map_err(|_| DeviceCryptoError::ArkEnvelopeOpenFailed)?;
    let binding_bytes = encode_ark_envelope_binding(expected_binding)?;
    let mut receiver_context = setup_receiver::<HpkeAead, HpkeKdf, HpkeKem>(
        &OpModeR::Base,
        &target_private_key,
        &encapsulated_key,
        &binding_bytes,
    )
    .map_err(|_| DeviceCryptoError::ArkEnvelopeOpenFailed)?;
    let ark_ciphertext_end = ARK_CIPHERTEXT_OFFSET + ACCOUNT_ROOT_KEY_LENGTH;
    let mut plaintext = Zeroizing::new(copy_array(
        &envelope.0[ARK_CIPHERTEXT_OFFSET..ark_ciphertext_end],
    ));
    let tag =
        AeadTag::<HpkeAead>::from_bytes(&envelope.0[ark_ciphertext_end..ARK_SIGNATURE_OFFSET])
            .map_err(|_| DeviceCryptoError::ArkEnvelopeOpenFailed)?;
    receiver_context
        .open_inout_detached(
            InOutBuf::from(plaintext.as_mut_slice()),
            &binding_bytes,
            &tag,
        )
        .map_err(|_| DeviceCryptoError::ArkEnvelopeOpenFailed)?;

    Ok(AccountRootKey(*plaintext))
}

fn encode_ark_envelope_binding(
    binding: ArkEnvelopeBinding,
) -> Result<[u8; ARK_ENCAPSULATED_KEY_OFFSET], DeviceCryptoError> {
    if binding.key_epoch == 0 {
        return Err(DeviceCryptoError::InvalidKeyEpoch);
    }

    let mut bytes = [0_u8; ARK_ENCAPSULATED_KEY_OFFSET];
    bytes[..4].copy_from_slice(&ARK_ENVELOPE_MAGIC);
    bytes[4..6].copy_from_slice(&ARK_ENVELOPE_VERSION.to_be_bytes());
    bytes[6..8].copy_from_slice(&ARK_ENVELOPE_SUITE_ID.to_be_bytes());
    bytes[8..10].copy_from_slice(&ARK_ENVELOPE_FLAGS.to_be_bytes());
    bytes[10..12].copy_from_slice(&ARK_ENVELOPE_RESERVED.to_be_bytes());
    bytes[ARK_USER_OFFSET..ARK_ISSUER_DEVICE_OFFSET].copy_from_slice(binding.user_id.as_bytes());
    bytes[ARK_ISSUER_DEVICE_OFFSET..ARK_TARGET_DEVICE_OFFSET]
        .copy_from_slice(binding.issuer_device_id.as_bytes());
    bytes[ARK_TARGET_DEVICE_OFFSET..ARK_EPOCH_OFFSET]
        .copy_from_slice(binding.target_device_id.as_bytes());
    bytes[ARK_EPOCH_OFFSET..ARK_ISSUER_SIGNING_KEY_OFFSET]
        .copy_from_slice(&binding.key_epoch.to_be_bytes());
    bytes[ARK_ISSUER_SIGNING_KEY_OFFSET..ARK_ISSUER_KEY_AGREEMENT_OFFSET]
        .copy_from_slice(binding.issuer_signing_public_key.as_bytes());
    bytes[ARK_ISSUER_KEY_AGREEMENT_OFFSET..ARK_TARGET_SIGNING_KEY_OFFSET]
        .copy_from_slice(binding.issuer_key_agreement_public_key.as_bytes());
    bytes[ARK_TARGET_SIGNING_KEY_OFFSET..ARK_TARGET_KEY_AGREEMENT_OFFSET]
        .copy_from_slice(binding.target_signing_public_key.as_bytes());
    bytes[ARK_TARGET_KEY_AGREEMENT_OFFSET..ARK_ENCAPSULATED_KEY_OFFSET]
        .copy_from_slice(binding.target_key_agreement_public_key.as_bytes());
    Ok(bytes)
}

struct HpkeRngAdapter<'a, R>(&'a mut R);

struct PublicKeyValidationRng;

impl hpke::rand_core::TryRng for PublicKeyValidationRng {
    type Error = Infallible;

    fn try_next_u32(&mut self) -> Result<u32, Self::Error> {
        Ok(0xa5a5_a5a5)
    }

    fn try_next_u64(&mut self) -> Result<u64, Self::Error> {
        Ok(0xa5a5_a5a5_a5a5_a5a5)
    }

    fn try_fill_bytes(&mut self, destination: &mut [u8]) -> Result<(), Self::Error> {
        destination.fill(0xa5);
        Ok(())
    }
}

impl hpke::rand_core::TryCryptoRng for PublicKeyValidationRng {}

impl<R> hpke::rand_core::TryRng for HpkeRngAdapter<'_, R>
where
    R: RngCore,
{
    type Error = Infallible;

    fn try_next_u32(&mut self) -> Result<u32, Self::Error> {
        Ok(self.0.next_u32())
    }

    fn try_next_u64(&mut self) -> Result<u64, Self::Error> {
        Ok(self.0.next_u64())
    }

    fn try_fill_bytes(&mut self, destination: &mut [u8]) -> Result<(), Self::Error> {
        self.0.fill_bytes(destination);
        Ok(())
    }
}

impl<R> hpke::rand_core::TryCryptoRng for HpkeRngAdapter<'_, R> where R: CryptoRng + RngCore {}

fn copy_array<const LENGTH: usize>(bytes: &[u8]) -> [u8; LENGTH] {
    let mut result = [0_u8; LENGTH];
    result.copy_from_slice(bytes);
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use rand::{CryptoRng, RngCore};

    const KDPF_VECTOR_MESSAGE_HEX: &str = concat!(
        "4b44504600010200010101010101410181010101010101010202020202024202",
        "820202020202020203030303030343038303030303030303000001a3185c5000",
        "4444444444444444444444444444444444444444444444444444444444444444",
        "d04ab232742bb4ab3a1368bd4615e4e6d0224ab71a016baf8520a332c9778737",
        "0faa684ed28867b97f4a6a2dee5df8ce974e76b7018e3f22a1c4cf2678570f20",
        "86f1a80acbdf6dd0f3484c482165676ff6fb7d647a03e83199748ccb07b76512",
        "e04055b0843aa8d0b950718488300d4d502ea63a14e21f2cd42fdfe34d43dda4",
    );
    const KDPF_VECTOR_SIGNATURE_HEX: &str = concat!(
        "c60453913cdba82d72423d7e1cd7d0a1110e1e41f817423fa934c1b53db66105",
        "ad1975dba96dd13b68fff6363280aa51bc5984fa17bafe8c384fea420ad74c04",
    );
    const KAEK_VECTOR_HEX: &str = concat!(
        "4b41454b00010001000000000404040404044404840404040404040405050505",
        "0505450585050505050505050606060606064606860606060606060600000007",
        "d04ab232742bb4ab3a1368bd4615e4e6d0224ab71a016baf8520a332c9778737",
        "0faa684ed28867b97f4a6a2dee5df8ce974e76b7018e3f22a1c4cf2678570f20",
        "17cb79fb2b4120f2b1ec65e4198d6e08b28e813feb01e4a400839b85e18080ce",
        "ff2ee45601ec1b67310c7790404585ae697331eee1c1f8cf2419731c1fff3e6b",
        "b176a752118398855621a5bdcd51896a395e0f9138df339a27b5a73e518b4a2f",
        "20bf47f00a917d0d0520e3420facf9d36ce1771fb956191771f1b8e0e40ae813",
        "e98bacb23b51963254270d9138756d3d1f39dbd132b81cbc37426546561bd9cf",
        "bdb267f3edb375d9a0ffce02ca56e28c36cc9e0370ba9cda7b1dff095f8a8b48",
        "cc069092134f6e90a13278777b12fe0e",
    );

    struct TestRng(u8);

    impl RngCore for TestRng {
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
            for byte in destination {
                *byte = self.0;
                self.0 = self.0.wrapping_add(1);
            }
        }

        fn try_fill_bytes(&mut self, destination: &mut [u8]) -> Result<(), rand::Error> {
            self.fill_bytes(destination);
            Ok(())
        }
    }

    impl CryptoRng for TestRng {}

    struct FixedRng {
        bytes: [u8; 32],
        offset: usize,
    }

    impl FixedRng {
        fn new(bytes: [u8; 32]) -> Self {
            Self { bytes, offset: 0 }
        }
    }

    impl RngCore for FixedRng {
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
            let end = self.offset + destination.len();
            assert!(end <= self.bytes.len(), "固定随机向量不得被重复使用");
            destination.copy_from_slice(&self.bytes[self.offset..end]);
            self.offset = end;
        }

        fn try_fill_bytes(&mut self, destination: &mut [u8]) -> Result<(), rand::Error> {
            self.fill_bytes(destination);
            Ok(())
        }
    }

    impl CryptoRng for FixedRng {}

    fn uuid_v4(seed: u8) -> [u8; 16] {
        let mut bytes = [seed; 16];
        bytes[6] = 0x40 | (seed & 0x0f);
        bytes[8] = 0x80 | (seed & 0x3f);
        bytes
    }

    fn hex_array<const LENGTH: usize>(hex: &str) -> [u8; LENGTH] {
        assert_eq!(hex.len(), LENGTH * 2);
        let mut bytes = [0_u8; LENGTH];
        for (index, byte) in bytes.iter_mut().enumerate() {
            *byte = u8::from_str_radix(&hex[index * 2..index * 2 + 2], 16)
                .expect("RFC 十六进制测试向量应有效");
        }
        bytes
    }

    fn device_proof_fixture() -> (DeviceProofFields, DeviceProofMessage, DeviceProofSignature) {
        let signing_key = DeviceSigningPrivateKey::from_seed([0x11; 32]);
        let agreement_key =
            DeviceKeyAgreementPrivateKey::from_bytes([0x22; 32]).expect("X25519 私钥应有效");
        let fields = DeviceProofFields {
            kind: DeviceProofKind::LoginFinish,
            attempt_id: OpaqueAttemptId::new(uuid_v4(1)).expect("attempt UUID 应有效"),
            account_binding: AccountBindingId::new(uuid_v4(2)).expect("账户绑定 UUID 应有效"),
            device_id: DeviceId::new(uuid_v4(3)).expect("设备 UUID 应有效"),
            expires_at_ms: 1_800_000_000_000,
            challenge: DeviceProofChallenge::from_bytes([0x44; 32]),
            signing_public_key: signing_key.public_key(),
            key_agreement_public_key: agreement_key.public_key(),
            opaque_finish_hash: Sha256Digest::of(b"OPAQUE finish"),
            envelope_hash: Sha256Digest::of(b"ARK envelope"),
        };
        let message = DeviceProofMessage::new(fields).expect("设备证明字段应有效");
        let signature = message.sign(&signing_key).expect("设备证明签名应成功");
        (fields, message, signature)
    }

    struct ArkFixture {
        envelope: ArkEnvelope,
        binding: ArkEnvelopeBinding,
        issuer_signing_key: DeviceSigningPrivateKey,
        target_private_key: DeviceKeyAgreementPrivateKey,
    }

    fn ark_fixture() -> ArkFixture {
        let issuer_signing_key = DeviceSigningPrivateKey::from_seed([0x11; 32]);
        let issuer_agreement_key = DeviceKeyAgreementPrivateKey::from_bytes([0x22; 32])
            .expect("签发设备 X25519 私钥应有效");
        let target_signing_key = DeviceSigningPrivateKey::from_seed([0x33; 32]);
        let target_private_key = DeviceKeyAgreementPrivateKey::from_bytes([0x44; 32])
            .expect("目标设备 X25519 私钥应有效");
        let binding = ArkEnvelopeBinding {
            user_id: UserId::new(uuid_v4(4)).expect("用户 UUID 应有效"),
            issuer_device_id: DeviceId::new(uuid_v4(5)).expect("签发设备 UUID 应有效"),
            target_device_id: DeviceId::new(uuid_v4(6)).expect("目标设备 UUID 应有效"),
            key_epoch: 7,
            issuer_signing_public_key: issuer_signing_key.public_key(),
            issuer_key_agreement_public_key: issuer_agreement_key.public_key(),
            target_signing_public_key: target_signing_key.public_key(),
            target_key_agreement_public_key: target_private_key.public_key(),
        };
        let ark = AccountRootKey::from_bytes([0x55; ACCOUNT_ROOT_KEY_LENGTH]);
        let envelope = seal_ark_envelope(&mut TestRng(0x66), &ark, binding, &issuer_signing_key)
            .expect("ARK 信封密封应成功");
        ArkFixture {
            envelope,
            binding,
            issuer_signing_key,
            target_private_key,
        }
    }

    #[test]
    fn x25519_secrets_have_compile_time_zeroize_on_drop_contract() {
        fn require_zeroize_on_drop<T: ZeroizeOnDrop>() {}

        require_zeroize_on_drop::<x25519_dalek::StaticSecret>();
        require_zeroize_on_drop::<x25519_dalek::SharedSecret>();
    }

    #[test]
    fn device_proof_round_trip_uses_fixed_wire_format() {
        let signing_key = DeviceSigningPrivateKey::from_seed([0x11; 32]);
        let agreement_key =
            DeviceKeyAgreementPrivateKey::from_bytes([0x22; 32]).expect("X25519 私钥应有效");
        let fields = DeviceProofFields {
            kind: DeviceProofKind::RegistrationFinish,
            attempt_id: OpaqueAttemptId::new(uuid_v4(1)).expect("attempt UUID 应有效"),
            account_binding: AccountBindingId::new(uuid_v4(2)).expect("账户绑定 UUID 应有效"),
            device_id: DeviceId::new(uuid_v4(3)).expect("设备 UUID 应有效"),
            expires_at_ms: 1_800_000_000_000,
            challenge: DeviceProofChallenge::from_bytes([0x44; 32]),
            signing_public_key: signing_key.public_key(),
            key_agreement_public_key: agreement_key.public_key(),
            opaque_finish_hash: Sha256Digest::of(b"OPAQUE finish"),
            envelope_hash: Sha256Digest::of(b"ARK envelope"),
        };

        let message = DeviceProofMessage::new(fields).expect("设备证明字段应有效");
        let signature = message.sign(&signing_key).expect("设备证明签名应成功");

        assert_eq!(message.as_bytes().len(), DEVICE_PROOF_MESSAGE_LENGTH);
        assert_eq!(&message.as_bytes()[..4], b"KDPF");
        assert_eq!(&message.as_bytes()[4..6], &1_u16.to_be_bytes());
        assert_eq!(
            message.as_bytes()[6],
            DeviceProofKind::RegistrationFinish as u8
        );
        assert_eq!(message.as_bytes()[7], 0);
        assert_eq!(&message.as_bytes()[8..24], fields.attempt_id.as_bytes());
        assert_eq!(
            &message.as_bytes()[24..40],
            fields.account_binding.as_bytes()
        );
        assert_eq!(&message.as_bytes()[40..56], fields.device_id.as_bytes());
        assert_eq!(
            &message.as_bytes()[56..64],
            &fields.expires_at_ms.to_be_bytes()
        );
        assert_eq!(&message.as_bytes()[64..96], fields.challenge.as_bytes());
        assert_eq!(
            &message.as_bytes()[96..128],
            fields.signing_public_key.as_bytes()
        );
        assert_eq!(
            &message.as_bytes()[128..160],
            fields.key_agreement_public_key.as_bytes()
        );
        assert_eq!(
            &message.as_bytes()[160..192],
            fields.opaque_finish_hash.as_bytes()
        );
        assert_eq!(
            &message.as_bytes()[192..224],
            fields.envelope_hash.as_bytes()
        );
        assert_eq!(signature.as_bytes().len(), DEVICE_PROOF_SIGNATURE_LENGTH);
        message
            .verify_expected(fields, &signature)
            .expect("设备证明验签应成功");
        DeviceProofMessage::from_bytes(message.as_bytes()).expect("线格式应可严格解析");
    }

    #[test]
    fn ark_envelope_round_trip_uses_fixed_hpke_wire_format() {
        let issuer_signing_key = DeviceSigningPrivateKey::from_seed([0x11; 32]);
        let issuer_agreement_key = DeviceKeyAgreementPrivateKey::from_bytes([0x22; 32])
            .expect("签发设备 X25519 私钥应有效");
        let target_signing_key = DeviceSigningPrivateKey::from_seed([0x33; 32]);
        let target_agreement_key = DeviceKeyAgreementPrivateKey::from_bytes([0x44; 32])
            .expect("目标设备 X25519 私钥应有效");
        let binding = ArkEnvelopeBinding {
            user_id: UserId::new(uuid_v4(4)).expect("用户 UUID 应有效"),
            issuer_device_id: DeviceId::new(uuid_v4(5)).expect("签发设备 UUID 应有效"),
            target_device_id: DeviceId::new(uuid_v4(6)).expect("目标设备 UUID 应有效"),
            key_epoch: 7,
            issuer_signing_public_key: issuer_signing_key.public_key(),
            issuer_key_agreement_public_key: issuer_agreement_key.public_key(),
            target_signing_public_key: target_signing_key.public_key(),
            target_key_agreement_public_key: target_agreement_key.public_key(),
        };
        let ark = AccountRootKey::from_bytes([0x55; ACCOUNT_ROOT_KEY_LENGTH]);
        let mut rng = TestRng(0x66);

        let envelope = seal_ark_envelope(&mut rng, &ark, binding, &issuer_signing_key)
            .expect("ARK 信封密封应成功");
        let opened = open_ark_envelope(&envelope, binding, &target_agreement_key)
            .expect("ARK 信封打开应成功");

        assert_eq!(envelope.as_bytes().len(), ARK_ENVELOPE_LENGTH);
        assert_eq!(&envelope.as_bytes()[..4], b"KAEK");
        assert_eq!(&envelope.as_bytes()[4..6], &1_u16.to_be_bytes());
        assert_eq!(&envelope.as_bytes()[6..8], &1_u16.to_be_bytes());
        assert_eq!(&envelope.as_bytes()[8..12], &[0; 4]);
        assert_eq!(&envelope.as_bytes()[12..28], binding.user_id.as_bytes());
        assert_eq!(
            &envelope.as_bytes()[28..44],
            binding.issuer_device_id.as_bytes()
        );
        assert_eq!(
            &envelope.as_bytes()[44..60],
            binding.target_device_id.as_bytes()
        );
        assert_eq!(
            &envelope.as_bytes()[60..64],
            &binding.key_epoch.to_be_bytes()
        );
        assert_eq!(
            &envelope.as_bytes()[64..96],
            binding.issuer_signing_public_key.as_bytes()
        );
        assert_eq!(
            &envelope.as_bytes()[96..128],
            binding.issuer_key_agreement_public_key.as_bytes()
        );
        assert_eq!(
            &envelope.as_bytes()[128..160],
            binding.target_signing_public_key.as_bytes()
        );
        assert_eq!(
            &envelope.as_bytes()[160..192],
            binding.target_key_agreement_public_key.as_bytes()
        );
        assert_eq!(
            envelope.as_bytes()[192..224].len(),
            ARK_HPKE_ENCAPSULATED_KEY_LENGTH
        );
        assert_eq!(
            envelope.as_bytes()[224..272].len(),
            ARK_HPKE_CIPHERTEXT_LENGTH
        );
        assert_eq!(
            envelope.as_bytes()[272..336].len(),
            ARK_ENVELOPE_SIGNATURE_LENGTH
        );
        assert_eq!(opened.as_bytes(), ark.as_bytes());
        ArkEnvelope::from_bytes(envelope.as_bytes()).expect("ARK 信封线格式应可严格解析");
    }

    #[test]
    fn cross_language_wire_vectors_are_stable() {
        let (_, message, signature) = device_proof_fixture();
        let fixture = ark_fixture();

        assert_eq!(
            message.as_bytes(),
            &hex_array::<DEVICE_PROOF_MESSAGE_LENGTH>(KDPF_VECTOR_MESSAGE_HEX)
        );
        assert_eq!(
            signature.as_bytes(),
            &hex_array::<DEVICE_PROOF_SIGNATURE_LENGTH>(KDPF_VECTOR_SIGNATURE_HEX)
        );
        assert_eq!(
            fixture.envelope.as_bytes(),
            &hex_array::<ARK_ENVELOPE_LENGTH>(KAEK_VECTOR_HEX)
        );
    }

    #[test]
    fn device_proof_rejects_length_version_kind_flags_and_signature_boundaries() {
        let (_, message, signature) = device_proof_fixture();
        let mut too_long = [0_u8; DEVICE_PROOF_MESSAGE_LENGTH + 1];
        too_long[..DEVICE_PROOF_MESSAGE_LENGTH].copy_from_slice(message.as_bytes());

        assert!(matches!(
            DeviceProofMessage::from_bytes(&message.as_bytes()[..DEVICE_PROOF_MESSAGE_LENGTH - 1]),
            Err(DeviceCryptoError::InvalidDeviceProofLength {
                expected: DEVICE_PROOF_MESSAGE_LENGTH,
                actual
            }) if actual == DEVICE_PROOF_MESSAGE_LENGTH - 1
        ));
        assert!(matches!(
            DeviceProofMessage::from_bytes(&too_long),
            Err(DeviceCryptoError::InvalidDeviceProofLength {
                expected: DEVICE_PROOF_MESSAGE_LENGTH,
                actual
            }) if actual == DEVICE_PROOF_MESSAGE_LENGTH + 1
        ));

        let mut wrong_version = *message.as_bytes();
        wrong_version[4..6].copy_from_slice(&2_u16.to_be_bytes());
        assert!(matches!(
            DeviceProofMessage::from_bytes(&wrong_version),
            Err(DeviceCryptoError::UnsupportedDeviceProofVersion(2))
        ));

        let mut wrong_kind = *message.as_bytes();
        wrong_kind[6] = 0xff;
        assert!(matches!(
            DeviceProofMessage::from_bytes(&wrong_kind),
            Err(DeviceCryptoError::UnsupportedDeviceProofKind(0xff))
        ));

        let mut wrong_flags = *message.as_bytes();
        wrong_flags[7] = 1;
        assert!(matches!(
            DeviceProofMessage::from_bytes(&wrong_flags),
            Err(DeviceCryptoError::UnsupportedDeviceProofFlags(1))
        ));
        assert!(matches!(
            DeviceProofSignature::from_bytes(
                &signature.as_bytes()[..DEVICE_PROOF_SIGNATURE_LENGTH - 1]
            ),
            Err(DeviceCryptoError::InvalidDeviceProofSignatureLength { .. })
        ));
        assert!(matches!(
            DeviceProofSignature::from_bytes(&[0_u8; DEVICE_PROOF_SIGNATURE_LENGTH + 1]),
            Err(DeviceCryptoError::InvalidDeviceProofSignatureLength { .. })
        ));
    }

    #[test]
    fn device_proof_rejects_tampering_in_every_bound_segment() {
        let (fields, message, signature) = device_proof_fixture();
        let segments = [
            ("attempt", PROOF_ATTEMPT_OFFSET),
            ("account", PROOF_ACCOUNT_OFFSET),
            ("device", PROOF_DEVICE_OFFSET),
            ("expires", PROOF_EXPIRES_OFFSET),
            ("challenge", PROOF_CHALLENGE_OFFSET),
            ("signing key", PROOF_SIGNING_KEY_OFFSET),
            ("key agreement", PROOF_KEY_AGREEMENT_OFFSET),
            ("OPAQUE finish hash", PROOF_OPAQUE_HASH_OFFSET),
            ("envelope hash", PROOF_ENVELOPE_HASH_OFFSET),
        ];

        for (name, offset) in segments {
            let mut tampered = *message.as_bytes();
            tampered[offset] ^= 1;
            let rejected = match DeviceProofMessage::from_bytes(&tampered) {
                Ok(parsed) => parsed.verify_expected(fields, &signature).is_err(),
                Err(_) => true,
            };
            assert!(rejected, "设备证明字段 {name} 被篡改后必须拒绝");
        }
    }

    #[test]
    fn device_proof_rejects_wrong_device_key_and_invalid_identifiers() {
        let (mut fields, message, signature) = device_proof_fixture();
        let expected_fields = fields;
        fields.device_id = DeviceId::new(uuid_v4(9)).expect("另一设备 UUID 应有效");
        let wrong_device_message = DeviceProofMessage::new(fields).expect("另一设备证明字段应有效");

        assert!(matches!(
            wrong_device_message.verify_expected(expected_fields, &signature),
            Err(DeviceCryptoError::DeviceProofBindingMismatch)
        ));
        assert!(matches!(
            message.sign(&DeviceSigningPrivateKey::from_seed([0x99; 32])),
            Err(DeviceCryptoError::SigningKeyMismatch)
        ));

        let attacker_key = DeviceSigningPrivateKey::from_seed([0x99; 32]);
        fields.signing_public_key = attacker_key.public_key();
        let substituted_message =
            DeviceProofMessage::new(fields).expect("替换公钥后的线格式仍应有效");
        let substituted_signature = substituted_message
            .sign(&attacker_key)
            .expect("攻击者可用自己的私钥签名");
        assert!(matches!(
            substituted_message.verify_expected(expected_fields, &substituted_signature),
            Err(DeviceCryptoError::DeviceProofBindingMismatch)
        ));

        assert!(matches!(
            DeviceId::new([0; UUID_LENGTH]),
            Err(DeviceCryptoError::InvalidUuidV4)
        ));
        assert!(matches!(
            DeviceKeyAgreementPublicKey::from_bytes([0; DEVICE_PUBLIC_KEY_LENGTH]),
            Err(DeviceCryptoError::InvalidKeyAgreementPublicKey)
        ));
        assert!(matches!(
            DeviceSigningPublicKey::from_bytes([0; DEVICE_PUBLIC_KEY_LENGTH]),
            Err(DeviceCryptoError::InvalidSigningPublicKey)
        ));
        let mut low_order_key = [0_u8; DEVICE_PUBLIC_KEY_LENGTH];
        low_order_key[0] = 1;
        assert!(matches!(
            DeviceKeyAgreementPublicKey::from_bytes(low_order_key),
            Err(DeviceCryptoError::InvalidKeyAgreementPublicKey)
        ));

        fields.expires_at_ms = 0;
        assert!(matches!(
            DeviceProofMessage::new(fields),
            Err(DeviceCryptoError::InvalidExpiry)
        ));
    }

    #[test]
    fn device_proof_rejects_stale_attempt_with_valid_signature() {
        let (expected_fields, _, _) = device_proof_fixture();
        let signing_key = DeviceSigningPrivateKey::from_seed([0x11; 32]);
        let mut stale_fields = expected_fields;
        stale_fields.attempt_id = OpaqueAttemptId::new(uuid_v4(9)).expect("旧 attempt UUID 应有效");
        let stale_message =
            DeviceProofMessage::new(stale_fields).expect("旧 attempt 消息仍是合法线格式");
        let stale_signature = stale_message
            .sign(&signing_key)
            .expect("旧 attempt 的设备签名本身应有效");

        assert!(matches!(
            stale_message.verify_expected(expected_fields, &stale_signature),
            Err(DeviceCryptoError::DeviceProofBindingMismatch)
        ));
    }

    #[test]
    fn ark_envelope_rejects_length_version_suite_flags_and_reserved_boundaries() {
        let fixture = ark_fixture();
        let mut too_long = [0_u8; ARK_ENVELOPE_LENGTH + 1];
        too_long[..ARK_ENVELOPE_LENGTH].copy_from_slice(fixture.envelope.as_bytes());

        assert!(matches!(
            ArkEnvelope::from_bytes(&fixture.envelope.as_bytes()[..ARK_ENVELOPE_LENGTH - 1]),
            Err(DeviceCryptoError::InvalidArkEnvelopeLength { .. })
        ));
        assert!(matches!(
            ArkEnvelope::from_bytes(&too_long),
            Err(DeviceCryptoError::InvalidArkEnvelopeLength { .. })
        ));

        let mut wrong_version = *fixture.envelope.as_bytes();
        wrong_version[4..6].copy_from_slice(&2_u16.to_be_bytes());
        assert!(matches!(
            ArkEnvelope::from_bytes(&wrong_version),
            Err(DeviceCryptoError::UnsupportedArkEnvelopeVersion(2))
        ));

        let mut wrong_suite = *fixture.envelope.as_bytes();
        wrong_suite[6..8].copy_from_slice(&2_u16.to_be_bytes());
        assert!(matches!(
            ArkEnvelope::from_bytes(&wrong_suite),
            Err(DeviceCryptoError::UnsupportedArkEnvelopeSuite(2))
        ));

        let mut wrong_flags = *fixture.envelope.as_bytes();
        wrong_flags[8..10].copy_from_slice(&1_u16.to_be_bytes());
        assert!(matches!(
            ArkEnvelope::from_bytes(&wrong_flags),
            Err(DeviceCryptoError::UnsupportedArkEnvelopeFlags(1))
        ));

        let mut wrong_reserved = *fixture.envelope.as_bytes();
        wrong_reserved[10..12].copy_from_slice(&1_u16.to_be_bytes());
        assert!(matches!(
            ArkEnvelope::from_bytes(&wrong_reserved),
            Err(DeviceCryptoError::UnsupportedArkEnvelopeReserved(1))
        ));
    }

    #[test]
    fn ark_envelope_rejects_tampering_in_every_wire_segment() {
        let fixture = ark_fixture();
        let segments = [
            ("magic", 0),
            ("version", 5),
            ("suite", 7),
            ("flags", 9),
            ("reserved", 11),
            ("user", ARK_USER_OFFSET),
            ("issuer device", ARK_ISSUER_DEVICE_OFFSET),
            ("target device", ARK_TARGET_DEVICE_OFFSET),
            ("epoch", ARK_EPOCH_OFFSET),
            ("issuer signing key", ARK_ISSUER_SIGNING_KEY_OFFSET),
            ("issuer X25519 key", ARK_ISSUER_KEY_AGREEMENT_OFFSET),
            ("target signing key", ARK_TARGET_SIGNING_KEY_OFFSET),
            ("target X25519 key", ARK_TARGET_KEY_AGREEMENT_OFFSET),
            ("encapsulated key", ARK_ENCAPSULATED_KEY_OFFSET),
            ("ciphertext", ARK_CIPHERTEXT_OFFSET),
            ("signature", ARK_SIGNATURE_OFFSET),
        ];

        for (name, offset) in segments {
            let mut tampered = *fixture.envelope.as_bytes();
            tampered[offset] ^= 1;
            let rejected = match ArkEnvelope::from_bytes(&tampered) {
                Ok(parsed) => verify_ark_envelope(&parsed, fixture.binding).is_err(),
                Err(_) => true,
            };
            assert!(rejected, "ARK 信封字段 {name} 被篡改后必须拒绝");
        }
    }

    #[test]
    fn ark_envelope_rejects_wrong_device_key_and_checks_signature_first() {
        let fixture = ark_fixture();
        let wrong_target_key =
            DeviceKeyAgreementPrivateKey::from_bytes([0x77; 32]).expect("另一目标设备私钥应有效");
        assert!(matches!(
            open_ark_envelope(&fixture.envelope, fixture.binding, &wrong_target_key),
            Err(DeviceCryptoError::KeyAgreementKeyMismatch)
        ));

        let mut wrong_binding = fixture.binding;
        wrong_binding.target_device_id =
            DeviceId::new(uuid_v4(10)).expect("另一目标设备 UUID 应有效");
        assert!(matches!(
            open_ark_envelope(
                &fixture.envelope,
                wrong_binding,
                &fixture.target_private_key
            ),
            Err(DeviceCryptoError::ArkEnvelopeBindingMismatch)
        ));

        let mut corrupted_signature = *fixture.envelope.as_bytes();
        corrupted_signature[ARK_SIGNATURE_OFFSET] ^= 1;
        let corrupted =
            ArkEnvelope::from_bytes(&corrupted_signature).expect("固定线格式仍应可解析");
        assert!(matches!(
            open_ark_envelope(&corrupted, fixture.binding, &wrong_target_key),
            Err(DeviceCryptoError::ArkEnvelopeSignatureInvalid)
        ));
    }

    #[test]
    fn ark_envelope_hpke_rejects_resigned_aad_change() {
        let fixture = ark_fixture();
        let mut changed_binding = fixture.binding;
        changed_binding.key_epoch = fixture.binding.key_epoch + 1;
        let mut changed = *fixture.envelope.as_bytes();
        changed[ARK_EPOCH_OFFSET..ARK_ISSUER_SIGNING_KEY_OFFSET]
            .copy_from_slice(&changed_binding.key_epoch.to_be_bytes());
        let signature = fixture
            .issuer_signing_key
            .signing_key()
            .sign(&changed[..ARK_SIGNATURE_OFFSET])
            .to_bytes();
        changed[ARK_SIGNATURE_OFFSET..].copy_from_slice(&signature);
        let changed = ArkEnvelope::from_bytes(&changed).expect("重新签名后的固定线格式应可解析");

        assert!(matches!(
            open_ark_envelope(&changed, changed_binding, &fixture.target_private_key),
            Err(DeviceCryptoError::ArkEnvelopeOpenFailed)
        ));
    }

    #[test]
    fn ark_envelope_seal_rejects_wrong_issuer_key_and_zero_epoch() {
        let fixture = ark_fixture();
        let ark = AccountRootKey::from_bytes([0x55; ACCOUNT_ROOT_KEY_LENGTH]);
        let wrong_issuer_key = DeviceSigningPrivateKey::from_seed([0x88; 32]);
        assert!(matches!(
            seal_ark_envelope(&mut TestRng(1), &ark, fixture.binding, &wrong_issuer_key),
            Err(DeviceCryptoError::SigningKeyMismatch)
        ));

        let mut zero_epoch = fixture.binding;
        zero_epoch.key_epoch = 0;
        assert!(matches!(
            seal_ark_envelope(
                &mut TestRng(1),
                &ark,
                zero_epoch,
                &fixture.issuer_signing_key
            ),
            Err(DeviceCryptoError::InvalidKeyEpoch)
        ));
    }

    #[test]
    fn ark_envelope_x25519_encapsulation_matches_rfc9180_vector() {
        let recipient_private_key = DeviceKeyAgreementPrivateKey::from_bytes(hex_array(
            "8057991eef8f1f1af18f4a9491d16a1ce333f695d4db8e38da75975c4478e0fb",
        ))
        .expect("RFC 9180 接收方私钥应有效");
        assert_eq!(
            recipient_private_key.public_key().as_bytes(),
            &hex_array::<32>("4310ee97d88cc1f088a5576c77ab0cf5c3ac797f3d95139c6c84b5429c59662a")
        );

        let issuer_signing_key = DeviceSigningPrivateKey::from_seed([0x11; 32]);
        let issuer_agreement_key = DeviceKeyAgreementPrivateKey::from_bytes([0x22; 32])
            .expect("签发设备 X25519 私钥应有效");
        let target_signing_key = DeviceSigningPrivateKey::from_seed([0x33; 32]);
        let binding = ArkEnvelopeBinding {
            user_id: UserId::new(uuid_v4(1)).expect("用户 UUID 应有效"),
            issuer_device_id: DeviceId::new(uuid_v4(2)).expect("签发设备 UUID 应有效"),
            target_device_id: DeviceId::new(uuid_v4(3)).expect("目标设备 UUID 应有效"),
            key_epoch: 1,
            issuer_signing_public_key: issuer_signing_key.public_key(),
            issuer_key_agreement_public_key: issuer_agreement_key.public_key(),
            target_signing_public_key: target_signing_key.public_key(),
            target_key_agreement_public_key: recipient_private_key.public_key(),
        };
        let envelope = seal_ark_envelope(
            &mut FixedRng::new(hex_array(
                "909a9b35d3dc4713a5e72a4da274b55d3d3821a37e5d099e74a647db583a904b",
            )),
            &AccountRootKey::from_bytes([0x44; ACCOUNT_ROOT_KEY_LENGTH]),
            binding,
            &issuer_signing_key,
        )
        .expect("RFC 9180 固定随机向量应可密封");

        assert_eq!(
            &envelope.as_bytes()[ARK_ENCAPSULATED_KEY_OFFSET..ARK_CIPHERTEXT_OFFSET],
            &hex_array::<32>("1afa08d3dec047a643885163f1180476fa7ddb54c6a8029ea33f95796bf2ac4a")
        );
    }
}
