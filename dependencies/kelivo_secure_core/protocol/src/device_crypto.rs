//! 设备身份与账户根密钥信封的唯一 v1 线格式。
//!
//! KDPF 使用固定 224 字节签名消息；KAEK 使用固定 336 字节自包含信封。
//! 两种格式都把算法、身份和用途写入被认证数据，避免调用方自行拼接上下文。

use std::{convert::Infallible, fmt};

use chacha20poly1305::{
    Tag, XChaCha20Poly1305, XNonce,
    aead::{AeadInOut, KeyInit as AeadKeyInit},
};
use curve25519_dalek::edwards::CompressedEdwardsY;
use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use hkdf::Hkdf;
use hmac::{Hmac, KeyInit as HmacKeyInit, Mac};
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
pub const DEVICE_PROOF_SIGNATURE_BUNDLE_LENGTH: usize = DEVICE_PROOF_SIGNATURE_LENGTH;
pub const PAIRING_SECRET_LENGTH: usize = 32;
pub const PAIRING_AUTHENTICATOR_LENGTH: usize = 32;
const PAIRING_AUTHENTICATOR_INFO: &[u8] = b"kelivo.pairing.authenticator.v1\0";
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
const DEVICE_STATE_MAGIC: [u8; 4] = *b"KDST";
pub const DEVICE_STATE_VERSION: u16 = 1;
pub const DEVICE_STATE_SUITE_ID: u16 = 1;
const DEVICE_STATE_FLAG_ARK_PRESENT: u16 = 1;
const DEVICE_STATE_SUPPORTED_FLAGS: u16 = DEVICE_STATE_FLAG_ARK_PRESENT;
const DEVICE_STATE_RESERVED: u16 = 0;
const DEVICE_STATE_HEADER_LENGTH: usize = 12;
const DEVICE_STATE_METADATA_LENGTH: usize = 40;
const DEVICE_STATE_NONCE_LENGTH: usize = 24;
const DEVICE_STATE_SECRET_LENGTH: usize = DEVICE_PRIVATE_KEY_LENGTH * 2 + ACCOUNT_ROOT_KEY_LENGTH;
const DEVICE_STATE_TAG_LENGTH: usize = 16;
const DEVICE_STATE_DEVICE_ID_OFFSET: usize = DEVICE_STATE_HEADER_LENGTH;
const DEVICE_STATE_KEY_VERSION_OFFSET: usize = DEVICE_STATE_DEVICE_ID_OFFSET + UUID_LENGTH;
const DEVICE_STATE_USER_ID_OFFSET: usize = DEVICE_STATE_KEY_VERSION_OFFSET + size_of::<u32>();
const DEVICE_STATE_KEY_EPOCH_OFFSET: usize = DEVICE_STATE_USER_ID_OFFSET + UUID_LENGTH;
const DEVICE_STATE_NONCE_OFFSET: usize = DEVICE_STATE_HEADER_LENGTH + DEVICE_STATE_METADATA_LENGTH;
const DEVICE_STATE_CIPHERTEXT_OFFSET: usize = DEVICE_STATE_NONCE_OFFSET + DEVICE_STATE_NONCE_LENGTH;
const DEVICE_STATE_TAG_OFFSET: usize = DEVICE_STATE_CIPHERTEXT_OFFSET + DEVICE_STATE_SECRET_LENGTH;
pub const DEVICE_STATE_BLOB_LENGTH: usize = DEVICE_STATE_TAG_OFFSET + DEVICE_STATE_TAG_LENGTH;
pub const DEVICE_STATE_KEY_LENGTH: usize = 32;

const PROOF_ATTEMPT_OFFSET: usize = DEVICE_PROOF_HEADER_LENGTH;
const PROOF_ACCOUNT_CONTEXT_OFFSET: usize = PROOF_ATTEMPT_OFFSET + UUID_LENGTH;
const PROOF_DEVICE_OFFSET: usize = PROOF_ACCOUNT_CONTEXT_OFFSET + UUID_LENGTH;
const PROOF_EXPIRES_OFFSET: usize = PROOF_DEVICE_OFFSET + UUID_LENGTH;
const PROOF_CHALLENGE_OFFSET: usize = PROOF_EXPIRES_OFFSET + size_of::<u64>();
const PROOF_SIGNING_KEY_OFFSET: usize = PROOF_CHALLENGE_OFFSET + DEVICE_PROOF_CHALLENGE_LENGTH;
const PROOF_KEY_AGREEMENT_OFFSET: usize = PROOF_SIGNING_KEY_OFFSET + DEVICE_PUBLIC_KEY_LENGTH;
const PROOF_PRIMARY_PAYLOAD_HASH_OFFSET: usize =
    PROOF_KEY_AGREEMENT_OFFSET + DEVICE_PUBLIC_KEY_LENGTH;
const PROOF_ENVELOPE_HASH_OFFSET: usize = PROOF_PRIMARY_PAYLOAD_HASH_OFFSET + SHA256_DIGEST_LENGTH;
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
    assert!(DEVICE_STATE_KEY_EPOCH_OFFSET + size_of::<u32>() == DEVICE_STATE_NONCE_OFFSET);
    assert!(DEVICE_STATE_BLOB_LENGTH == 188);
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DeviceCryptoError {
    InvalidUuidV4,
    InvalidExpiry,
    InvalidSigningPublicKey,
    InvalidKeyAgreementPublicKey,
    InvalidKeyAgreementPrivateKey,
    RandomnessUnavailable,
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
    InvalidPrimaryPayloadLength { expected: usize, actual: usize },
    InvalidEnvelopePayloadLength { expected: usize, actual: usize },
    InvalidPairingAuthenticatorLength { expected: usize, actual: usize },
    PairingAuthenticatorCryptoFailed,
    PairingAuthenticatorInvalid,
    InvalidDeviceStateMagic,
    UnsupportedDeviceStateVersion(u16),
    UnsupportedDeviceStateSuite(u16),
    UnsupportedDeviceStateFlags(u16),
    UnsupportedDeviceStateReserved(u16),
    InvalidDeviceStateLength { expected: usize, actual: usize },
    InvalidDeviceKeyVersion,
    DeviceStateBindingMismatch,
    DeviceStateCryptoFailed,
    DeviceStateAuthenticationFailed,
}

impl fmt::Display for DeviceCryptoError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidUuidV4 => formatter.write_str("设备密码学标识不是 RFC 4122 UUIDv4"),
            Self::InvalidExpiry => formatter.write_str("设备密码学过期时间无效"),
            Self::InvalidSigningPublicKey => formatter.write_str("Ed25519 公钥无效"),
            Self::InvalidKeyAgreementPublicKey => formatter.write_str("X25519 公钥无效"),
            Self::InvalidKeyAgreementPrivateKey => formatter.write_str("X25519 私钥无效"),
            Self::RandomnessUnavailable => formatter.write_str("系统随机源不可用"),
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
            Self::InvalidPrimaryPayloadLength { expected, actual } => write!(
                formatter,
                "设备证明主载荷长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::InvalidEnvelopePayloadLength { expected, actual } => write!(
                formatter,
                "设备证明信封长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::InvalidPairingAuthenticatorLength { expected, actual } => write!(
                formatter,
                "配对认证器长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::PairingAuthenticatorCryptoFailed => formatter.write_str("配对认证器派生失败"),
            Self::PairingAuthenticatorInvalid => formatter.write_str("配对认证器无效"),
            Self::InvalidDeviceStateMagic => formatter.write_str("设备秘密状态魔数无效"),
            Self::UnsupportedDeviceStateVersion(version) => {
                write!(formatter, "不支持的设备秘密状态版本：{version}")
            }
            Self::UnsupportedDeviceStateSuite(suite) => {
                write!(formatter, "不支持的设备秘密状态密码套件：{suite}")
            }
            Self::UnsupportedDeviceStateFlags(flags) => {
                write!(formatter, "设备秘密状态包含不支持的标志：{flags}")
            }
            Self::UnsupportedDeviceStateReserved(reserved) => {
                write!(formatter, "设备秘密状态保留字段必须为零，实际 {reserved}")
            }
            Self::InvalidDeviceStateLength { expected, actual } => write!(
                formatter,
                "设备秘密状态长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::InvalidDeviceKeyVersion => formatter.write_str("设备密钥版本必须为正整数"),
            Self::DeviceStateBindingMismatch => {
                formatter.write_str("设备秘密状态与身份或账户绑定不匹配")
            }
            Self::DeviceStateCryptoFailed => formatter.write_str("设备秘密状态密封失败"),
            Self::DeviceStateAuthenticationFailed => formatter.write_str("设备秘密状态认证失败"),
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

define_uuid_v4!(DeviceProofAttemptId);
define_uuid_v4!(AccountContextId);
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

fn is_strict_ed25519_point(bytes: &[u8; DEVICE_PUBLIC_KEY_LENGTH]) -> bool {
    let compressed = CompressedEdwardsY(*bytes);
    let Some(point) = compressed.decompress() else {
        return false;
    };

    point.compress().to_bytes() == *bytes && !point.is_small_order() && point.is_torsion_free()
}

fn strict_verifying_key(
    bytes: &[u8; DEVICE_PUBLIC_KEY_LENGTH],
) -> Result<VerifyingKey, DeviceCryptoError> {
    let public_key =
        VerifyingKey::from_bytes(bytes).map_err(|_| DeviceCryptoError::InvalidSigningPublicKey)?;
    if !is_strict_ed25519_point(bytes) {
        return Err(DeviceCryptoError::InvalidSigningPublicKey);
    }
    Ok(public_key)
}

fn verify_strict_device_signature(
    public_key: &VerifyingKey,
    message: &[u8],
    signature: &Signature,
) -> bool {
    let signature_bytes = signature.to_bytes();
    let signature_r = copy_array(&signature_bytes[..DEVICE_PUBLIC_KEY_LENGTH]);

    is_strict_ed25519_point(public_key.as_bytes())
        && is_strict_ed25519_point(&signature_r)
        && public_key.verify_strict(message, signature).is_ok()
}

impl DeviceSigningPublicKey {
    pub fn from_bytes(bytes: [u8; DEVICE_PUBLIC_KEY_LENGTH]) -> Result<Self, DeviceCryptoError> {
        strict_verifying_key(&bytes)?;
        Ok(Self(bytes))
    }

    pub const fn as_bytes(&self) -> &[u8; DEVICE_PUBLIC_KEY_LENGTH] {
        &self.0
    }

    fn verifying_key(&self) -> Result<VerifyingKey, DeviceCryptoError> {
        strict_verifying_key(&self.0)
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
pub struct DevicePublicKeys {
    pub signing: DeviceSigningPublicKey,
    pub key_agreement: DeviceKeyAgreementPublicKey,
}

pub struct DeviceIdentity {
    signing: DeviceSigningPrivateKey,
    key_agreement: DeviceKeyAgreementPrivateKey,
}

impl DeviceIdentity {
    pub fn generate<R>(rng: &mut R) -> Result<Self, DeviceCryptoError>
    where
        R: CryptoRng + RngCore,
    {
        let mut signing_seed = Zeroizing::new([0_u8; DEVICE_PRIVATE_KEY_LENGTH]);
        let mut key_agreement_bytes = Zeroizing::new([0_u8; DEVICE_PRIVATE_KEY_LENGTH]);
        rng.try_fill_bytes(signing_seed.as_mut_slice())
            .map_err(|_| DeviceCryptoError::RandomnessUnavailable)?;
        rng.try_fill_bytes(key_agreement_bytes.as_mut_slice())
            .map_err(|_| DeviceCryptoError::RandomnessUnavailable)?;
        Self::from_private_bytes(*signing_seed, *key_agreement_bytes)
    }

    fn from_private_bytes(
        signing_seed: [u8; DEVICE_PRIVATE_KEY_LENGTH],
        key_agreement_bytes: [u8; DEVICE_PRIVATE_KEY_LENGTH],
    ) -> Result<Self, DeviceCryptoError> {
        Ok(Self {
            signing: DeviceSigningPrivateKey::from_seed(signing_seed),
            key_agreement: DeviceKeyAgreementPrivateKey::from_bytes(key_agreement_bytes)?,
        })
    }

    pub fn public_keys(&self) -> DevicePublicKeys {
        DevicePublicKeys {
            signing: self.signing.public_key(),
            key_agreement: self.key_agreement.public_key(),
        }
    }

    pub fn sign_opaque_finish_proof(
        &self,
        kind: DeviceProofKind,
        context: DeviceProofContext,
        primary_payload: &[u8],
        envelope: &[u8],
    ) -> Result<DeviceProofSignature, DeviceCryptoError> {
        let (expected_primary_length, expected_envelope_length) = match kind {
            DeviceProofKind::RegistrationFinish => {
                (crate::REGISTRATION_UPLOAD_LENGTH, ARK_ENVELOPE_LENGTH)
            }
            DeviceProofKind::LoginFinish => (crate::CREDENTIAL_FINALIZATION_LENGTH, 0),
            DeviceProofKind::PairingApprove => {
                return Err(DeviceCryptoError::UnsupportedDeviceProofKind(kind as u8));
            }
        };
        require_exact_length(primary_payload, expected_primary_length, true)?;
        require_exact_length(envelope, expected_envelope_length, false)?;
        if !envelope.is_empty() {
            ArkEnvelope::from_bytes(envelope)?;
        }
        self.build_and_sign_proof(kind, context, primary_payload, envelope)
            .map(|(_, signature)| signature)
    }

    pub fn sign_pairing_approval_proof(
        &self,
        context: DeviceProofContext,
        pairing_secret: &[u8],
        envelope: &ArkEnvelope,
    ) -> Result<(DeviceProofSignature, PairingAuthenticator), DeviceCryptoError> {
        require_exact_length(pairing_secret, PAIRING_SECRET_LENGTH, true)?;
        let (message, signature) = self.build_and_sign_proof(
            DeviceProofKind::PairingApprove,
            context,
            pairing_secret,
            envelope.as_bytes(),
        )?;
        let authenticator = PairingAuthenticator::create(
            pairing_secret,
            &message,
            &signature,
            envelope.as_bytes(),
        )?;
        Ok((signature, authenticator))
    }

    fn build_and_sign_proof(
        &self,
        kind: DeviceProofKind,
        context: DeviceProofContext,
        primary_payload: &[u8],
        envelope: &[u8],
    ) -> Result<(DeviceProofMessage, DeviceProofSignature), DeviceCryptoError> {
        let public_keys = self.public_keys();
        let message = DeviceProofMessage::new(DeviceProofFields {
            kind,
            attempt_id: context.attempt_id,
            account_context_id: context.account_context_id,
            device_id: context.device_id,
            expires_at_ms: context.expires_at_ms,
            challenge: context.challenge,
            signing_public_key: public_keys.signing,
            key_agreement_public_key: public_keys.key_agreement,
            primary_payload_hash: Sha256Digest::of(primary_payload),
            envelope_hash: Sha256Digest::of(envelope),
        })?;
        let signature = message.sign(&self.signing)?;
        Ok((message, signature))
    }

    pub fn seal_ark_envelope<R>(
        &self,
        rng: &mut R,
        ark: &AccountRootKey,
        binding: ArkEnvelopeBinding,
    ) -> Result<ArkEnvelope, DeviceCryptoError>
    where
        R: CryptoRng + RngCore,
    {
        seal_ark_envelope(rng, ark, binding, &self.signing)
    }

    pub fn open_pairing_approval(
        &self,
        expected: PairingApprovalExpected,
        pairing_secret: &[u8],
        proof_signature: &[u8],
        authenticator: &[u8],
        envelope: &[u8],
    ) -> Result<AccountRootKey, DeviceCryptoError> {
        require_exact_length(pairing_secret, PAIRING_SECRET_LENGTH, true)?;
        let proof_signature = DeviceProofSignature::from_bytes(proof_signature)?;
        let authenticator = PairingAuthenticator::from_bytes(authenticator)?;
        require_exact_length(envelope, ARK_ENVELOPE_LENGTH, false)?;
        let target_public_keys = self.public_keys();
        let proof_fields = DeviceProofFields {
            kind: DeviceProofKind::PairingApprove,
            attempt_id: expected.pairing_id,
            account_context_id: AccountContextId::new(*expected.user_id.as_bytes())?,
            device_id: expected.issuer_device_id,
            expires_at_ms: expected.expires_at_ms,
            challenge: expected.challenge,
            signing_public_key: expected.issuer_public_keys.signing,
            key_agreement_public_key: expected.issuer_public_keys.key_agreement,
            primary_payload_hash: Sha256Digest::of(pairing_secret),
            envelope_hash: Sha256Digest::of(envelope),
        };
        let proof_message = DeviceProofMessage::new(proof_fields)?;
        authenticator.verify(pairing_secret, &proof_message, &proof_signature, envelope)?;
        proof_message.verify_expected(proof_fields, &proof_signature)?;
        let envelope = ArkEnvelope::from_bytes(envelope)?;

        open_ark_envelope(
            &envelope,
            ArkEnvelopeBinding {
                user_id: expected.user_id,
                issuer_device_id: expected.issuer_device_id,
                target_device_id: expected.target_device_id,
                key_epoch: expected.key_epoch,
                issuer_signing_public_key: expected.issuer_public_keys.signing,
                issuer_key_agreement_public_key: expected.issuer_public_keys.key_agreement,
                target_signing_public_key: target_public_keys.signing,
                target_key_agreement_public_key: target_public_keys.key_agreement,
            },
            &self.key_agreement,
        )
    }
}

fn require_exact_length(
    bytes: &[u8],
    expected: usize,
    primary_payload: bool,
) -> Result<(), DeviceCryptoError> {
    if bytes.len() == expected {
        return Ok(());
    }
    if primary_payload {
        Err(DeviceCryptoError::InvalidPrimaryPayloadLength {
            expected,
            actual: bytes.len(),
        })
    } else {
        Err(DeviceCryptoError::InvalidEnvelopePayloadLength {
            expected,
            actual: bytes.len(),
        })
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum DeviceProofKind {
    RegistrationFinish = 1,
    LoginFinish = 2,
    PairingApprove = 3,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct DeviceProofContext {
    pub attempt_id: DeviceProofAttemptId,
    pub account_context_id: AccountContextId,
    pub device_id: DeviceId,
    pub expires_at_ms: u64,
    pub challenge: DeviceProofChallenge,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct PairingApprovalExpected {
    pub pairing_id: DeviceProofAttemptId,
    pub user_id: UserId,
    pub issuer_device_id: DeviceId,
    pub target_device_id: DeviceId,
    pub expires_at_ms: u64,
    pub challenge: DeviceProofChallenge,
    pub key_epoch: u32,
    pub issuer_public_keys: DevicePublicKeys,
}

impl DeviceProofKind {
    fn from_u8(value: u8) -> Result<Self, DeviceCryptoError> {
        match value {
            1 => Ok(Self::RegistrationFinish),
            2 => Ok(Self::LoginFinish),
            3 => Ok(Self::PairingApprove),
            _ => Err(DeviceCryptoError::UnsupportedDeviceProofKind(value)),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct DeviceProofFields {
    pub kind: DeviceProofKind,
    /// 注册/登录使用 OPAQUE attempt，配对批准使用 pairing request UUIDv4。
    pub attempt_id: DeviceProofAttemptId,
    /// 注册/登录使用 OPAQUE account binding，配对批准使用 user UUIDv4。
    pub account_context_id: AccountContextId,
    pub device_id: DeviceId,
    /// 服务端签发的毫秒 Unix 时间戳；零值永远无效。
    pub expires_at_ms: u64,
    /// 服务端为本次 finish 签发的 32 字节随机挑战。
    pub challenge: DeviceProofChallenge,
    pub signing_public_key: DeviceSigningPublicKey,
    pub key_agreement_public_key: DeviceKeyAgreementPublicKey,
    /// 按证明类型对 Rust 已校验的原始主载荷求 SHA-256。
    pub primary_payload_hash: Sha256Digest,
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
        bytes[PROOF_ATTEMPT_OFFSET..PROOF_ACCOUNT_CONTEXT_OFFSET]
            .copy_from_slice(fields.attempt_id.as_bytes());
        bytes[PROOF_ACCOUNT_CONTEXT_OFFSET..PROOF_DEVICE_OFFSET]
            .copy_from_slice(fields.account_context_id.as_bytes());
        bytes[PROOF_DEVICE_OFFSET..PROOF_EXPIRES_OFFSET]
            .copy_from_slice(fields.device_id.as_bytes());
        bytes[PROOF_EXPIRES_OFFSET..PROOF_CHALLENGE_OFFSET]
            .copy_from_slice(&fields.expires_at_ms.to_be_bytes());
        bytes[PROOF_CHALLENGE_OFFSET..PROOF_SIGNING_KEY_OFFSET]
            .copy_from_slice(fields.challenge.as_bytes());
        bytes[PROOF_SIGNING_KEY_OFFSET..PROOF_KEY_AGREEMENT_OFFSET]
            .copy_from_slice(fields.signing_public_key.as_bytes());
        bytes[PROOF_KEY_AGREEMENT_OFFSET..PROOF_PRIMARY_PAYLOAD_HASH_OFFSET]
            .copy_from_slice(fields.key_agreement_public_key.as_bytes());
        bytes[PROOF_PRIMARY_PAYLOAD_HASH_OFFSET..PROOF_ENVELOPE_HASH_OFFSET]
            .copy_from_slice(fields.primary_payload_hash.as_bytes());
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

        DeviceProofAttemptId::new(copy_array(
            &bytes[PROOF_ATTEMPT_OFFSET..PROOF_ACCOUNT_CONTEXT_OFFSET],
        ))?;
        AccountContextId::new(copy_array(
            &bytes[PROOF_ACCOUNT_CONTEXT_OFFSET..PROOF_DEVICE_OFFSET],
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
            &bytes[PROOF_KEY_AGREEMENT_OFFSET..PROOF_PRIMARY_PAYLOAD_HASH_OFFSET],
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
        let public_key = expected_fields.signing_public_key.verifying_key()?;
        if !verify_strict_device_signature(
            &public_key,
            &self.0,
            &Signature::from_bytes(&signature.0),
        ) {
            return Err(DeviceCryptoError::DeviceProofSignatureInvalid);
        }
        Ok(())
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

pub struct PairingAuthenticator([u8; PAIRING_AUTHENTICATOR_LENGTH]);

impl PairingAuthenticator {
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, DeviceCryptoError> {
        if bytes.len() != PAIRING_AUTHENTICATOR_LENGTH {
            return Err(DeviceCryptoError::InvalidPairingAuthenticatorLength {
                expected: PAIRING_AUTHENTICATOR_LENGTH,
                actual: bytes.len(),
            });
        }
        Ok(Self(copy_array(bytes)))
    }

    pub const fn as_bytes(&self) -> &[u8; PAIRING_AUTHENTICATOR_LENGTH] {
        &self.0
    }

    fn create(
        pairing_secret: &[u8],
        message: &DeviceProofMessage,
        signature: &DeviceProofSignature,
        envelope: &[u8],
    ) -> Result<Self, DeviceCryptoError> {
        let key = derive_pairing_authenticator_key(pairing_secret)?;
        let mut mac = <Hmac<Sha256> as HmacKeyInit>::new_from_slice(key.as_slice())
            .map_err(|_| DeviceCryptoError::PairingAuthenticatorCryptoFailed)?;
        mac.update(message.as_bytes());
        mac.update(signature.as_bytes());
        mac.update(envelope);
        Ok(Self(mac.finalize().into_bytes().into()))
    }

    fn verify(
        &self,
        pairing_secret: &[u8],
        message: &DeviceProofMessage,
        signature: &DeviceProofSignature,
        envelope: &[u8],
    ) -> Result<(), DeviceCryptoError> {
        let key = derive_pairing_authenticator_key(pairing_secret)?;
        let mut mac = <Hmac<Sha256> as HmacKeyInit>::new_from_slice(key.as_slice())
            .map_err(|_| DeviceCryptoError::PairingAuthenticatorCryptoFailed)?;
        mac.update(message.as_bytes());
        mac.update(signature.as_bytes());
        mac.update(envelope);
        mac.verify_slice(&self.0)
            .map_err(|_| DeviceCryptoError::PairingAuthenticatorInvalid)
    }
}

fn derive_pairing_authenticator_key(
    pairing_secret: &[u8],
) -> Result<Zeroizing<[u8; PAIRING_AUTHENTICATOR_LENGTH]>, DeviceCryptoError> {
    require_exact_length(pairing_secret, PAIRING_SECRET_LENGTH, true)?;
    let mut key = Zeroizing::new([0_u8; PAIRING_AUTHENTICATOR_LENGTH]);
    Hkdf::<Sha256>::new(Some(&[]), pairing_secret)
        .expand(PAIRING_AUTHENTICATOR_INFO, key.as_mut_slice())
        .map_err(|_| DeviceCryptoError::PairingAuthenticatorCryptoFailed)?;
    Ok(key)
}

pub struct AccountRootKey([u8; ACCOUNT_ROOT_KEY_LENGTH]);

impl AccountRootKey {
    pub fn generate<R>(rng: &mut R) -> Result<Self, DeviceCryptoError>
    where
        R: CryptoRng + RngCore,
    {
        let mut bytes = Zeroizing::new([0_u8; ACCOUNT_ROOT_KEY_LENGTH]);
        rng.try_fill_bytes(bytes.as_mut_slice())
            .map_err(|_| DeviceCryptoError::RandomnessUnavailable)?;
        Ok(Self(*bytes))
    }

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
    let issuer_public_key = expected_binding.issuer_signing_public_key.verifying_key()?;
    if !verify_strict_device_signature(
        &issuer_public_key,
        &envelope.0[..ARK_SIGNATURE_OFFSET],
        &signature,
    ) {
        return Err(DeviceCryptoError::ArkEnvelopeSignatureInvalid);
    }
    Ok(())
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

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct DeviceStateAccountBinding {
    pub user_id: UserId,
    pub key_epoch: u32,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct DeviceStateBinding {
    pub device_id: DeviceId,
    pub key_version: u32,
    pub account: Option<DeviceStateAccountBinding>,
}

pub struct DeviceStateBlob([u8; DEVICE_STATE_BLOB_LENGTH]);

impl DeviceStateBlob {
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, DeviceCryptoError> {
        if bytes.len() != DEVICE_STATE_BLOB_LENGTH {
            return Err(DeviceCryptoError::InvalidDeviceStateLength {
                expected: DEVICE_STATE_BLOB_LENGTH,
                actual: bytes.len(),
            });
        }
        if bytes[..4] != DEVICE_STATE_MAGIC {
            return Err(DeviceCryptoError::InvalidDeviceStateMagic);
        }
        let version = u16::from_be_bytes(copy_array(&bytes[4..6]));
        if version != DEVICE_STATE_VERSION {
            return Err(DeviceCryptoError::UnsupportedDeviceStateVersion(version));
        }
        let suite = u16::from_be_bytes(copy_array(&bytes[6..8]));
        if suite != DEVICE_STATE_SUITE_ID {
            return Err(DeviceCryptoError::UnsupportedDeviceStateSuite(suite));
        }
        let flags = u16::from_be_bytes(copy_array(&bytes[8..10]));
        if flags & !DEVICE_STATE_SUPPORTED_FLAGS != 0 {
            return Err(DeviceCryptoError::UnsupportedDeviceStateFlags(flags));
        }
        let reserved = u16::from_be_bytes(copy_array(&bytes[10..12]));
        if reserved != DEVICE_STATE_RESERVED {
            return Err(DeviceCryptoError::UnsupportedDeviceStateReserved(reserved));
        }
        Ok(Self(copy_array(bytes)))
    }

    pub const fn as_bytes(&self) -> &[u8; DEVICE_STATE_BLOB_LENGTH] {
        &self.0
    }

    fn authenticated_binding(&self) -> Result<DeviceStateBinding, DeviceCryptoError> {
        let flags = u16::from_be_bytes(copy_array(&self.0[8..10]));
        let device_id = DeviceId::new(copy_array(
            &self.0[DEVICE_STATE_DEVICE_ID_OFFSET..DEVICE_STATE_KEY_VERSION_OFFSET],
        ))?;
        let key_version = u32::from_be_bytes(copy_array(
            &self.0[DEVICE_STATE_KEY_VERSION_OFFSET..DEVICE_STATE_USER_ID_OFFSET],
        ));
        if key_version == 0 {
            return Err(DeviceCryptoError::InvalidDeviceKeyVersion);
        }
        let user_id_bytes =
            copy_array(&self.0[DEVICE_STATE_USER_ID_OFFSET..DEVICE_STATE_KEY_EPOCH_OFFSET]);
        let key_epoch = u32::from_be_bytes(copy_array(
            &self.0[DEVICE_STATE_KEY_EPOCH_OFFSET..DEVICE_STATE_NONCE_OFFSET],
        ));
        let account = if flags & DEVICE_STATE_FLAG_ARK_PRESENT != 0 {
            if key_epoch == 0 {
                return Err(DeviceCryptoError::InvalidKeyEpoch);
            }
            Some(DeviceStateAccountBinding {
                user_id: UserId::new(user_id_bytes)?,
                key_epoch,
            })
        } else {
            if user_id_bytes != [0; UUID_LENGTH] || key_epoch != 0 {
                return Err(DeviceCryptoError::DeviceStateBindingMismatch);
            }
            None
        };
        Ok(DeviceStateBinding {
            device_id,
            key_version,
            account,
        })
    }
}

pub fn seal_device_state<R>(
    rng: &mut R,
    state_key: &[u8; DEVICE_STATE_KEY_LENGTH],
    identity: &DeviceIdentity,
    ark: Option<&AccountRootKey>,
    binding: DeviceStateBinding,
) -> Result<DeviceStateBlob, DeviceCryptoError>
where
    R: CryptoRng + RngCore,
{
    if binding.key_version == 0 {
        return Err(DeviceCryptoError::InvalidDeviceKeyVersion);
    }
    if ark.is_some() != binding.account.is_some() {
        return Err(DeviceCryptoError::DeviceStateBindingMismatch);
    }

    let mut bytes = [0_u8; DEVICE_STATE_BLOB_LENGTH];
    bytes[..4].copy_from_slice(&DEVICE_STATE_MAGIC);
    bytes[4..6].copy_from_slice(&DEVICE_STATE_VERSION.to_be_bytes());
    bytes[6..8].copy_from_slice(&DEVICE_STATE_SUITE_ID.to_be_bytes());
    let flags = if binding.account.is_some() {
        DEVICE_STATE_FLAG_ARK_PRESENT
    } else {
        0
    };
    bytes[8..10].copy_from_slice(&flags.to_be_bytes());
    bytes[10..12].copy_from_slice(&DEVICE_STATE_RESERVED.to_be_bytes());
    bytes[DEVICE_STATE_DEVICE_ID_OFFSET..DEVICE_STATE_KEY_VERSION_OFFSET]
        .copy_from_slice(binding.device_id.as_bytes());
    bytes[DEVICE_STATE_KEY_VERSION_OFFSET..DEVICE_STATE_USER_ID_OFFSET]
        .copy_from_slice(&binding.key_version.to_be_bytes());
    if let Some(account) = binding.account {
        if account.key_epoch == 0 {
            return Err(DeviceCryptoError::InvalidKeyEpoch);
        }
        bytes[DEVICE_STATE_USER_ID_OFFSET..DEVICE_STATE_KEY_EPOCH_OFFSET]
            .copy_from_slice(account.user_id.as_bytes());
        bytes[DEVICE_STATE_KEY_EPOCH_OFFSET..DEVICE_STATE_NONCE_OFFSET]
            .copy_from_slice(&account.key_epoch.to_be_bytes());
    }

    let mut nonce_bytes = [0_u8; DEVICE_STATE_NONCE_LENGTH];
    rng.try_fill_bytes(&mut nonce_bytes)
        .map_err(|_| DeviceCryptoError::RandomnessUnavailable)?;
    bytes[DEVICE_STATE_NONCE_OFFSET..DEVICE_STATE_CIPHERTEXT_OFFSET].copy_from_slice(&nonce_bytes);

    let mut plaintext = Zeroizing::new([0_u8; DEVICE_STATE_SECRET_LENGTH]);
    plaintext[..DEVICE_PRIVATE_KEY_LENGTH].copy_from_slice(&identity.signing.0);
    plaintext[DEVICE_PRIVATE_KEY_LENGTH..DEVICE_PRIVATE_KEY_LENGTH * 2]
        .copy_from_slice(&identity.key_agreement.0);
    if let Some(ark) = ark {
        plaintext[DEVICE_PRIVATE_KEY_LENGTH * 2..].copy_from_slice(&ark.0);
    }

    let cipher = XChaCha20Poly1305::new_from_slice(state_key)
        .map_err(|_| DeviceCryptoError::DeviceStateCryptoFailed)?;
    let nonce = XNonce::from(nonce_bytes);
    let tag = cipher
        .encrypt_inout_detached(
            &nonce,
            &bytes[..DEVICE_STATE_CIPHERTEXT_OFFSET],
            plaintext.as_mut_slice().into(),
        )
        .map_err(|_| DeviceCryptoError::DeviceStateCryptoFailed)?;
    bytes[DEVICE_STATE_CIPHERTEXT_OFFSET..DEVICE_STATE_TAG_OFFSET]
        .copy_from_slice(plaintext.as_slice());
    bytes[DEVICE_STATE_TAG_OFFSET..].copy_from_slice(tag.as_slice());
    Ok(DeviceStateBlob(bytes))
}

pub fn open_device_state(
    state_key: &[u8; DEVICE_STATE_KEY_LENGTH],
    blob: &DeviceStateBlob,
) -> Result<(DeviceStateBinding, DeviceIdentity, Option<AccountRootKey>), DeviceCryptoError> {
    let nonce_bytes: [u8; DEVICE_STATE_NONCE_LENGTH] = blob.0
        [DEVICE_STATE_NONCE_OFFSET..DEVICE_STATE_CIPHERTEXT_OFFSET]
        .try_into()
        .map_err(|_| DeviceCryptoError::DeviceStateAuthenticationFailed)?;
    let nonce = XNonce::from(nonce_bytes);
    let cipher = XChaCha20Poly1305::new_from_slice(state_key)
        .map_err(|_| DeviceCryptoError::DeviceStateCryptoFailed)?;
    let mut plaintext = Zeroizing::new([0_u8; DEVICE_STATE_SECRET_LENGTH]);
    plaintext.copy_from_slice(&blob.0[DEVICE_STATE_CIPHERTEXT_OFFSET..DEVICE_STATE_TAG_OFFSET]);
    let tag: &Tag = blob.0[DEVICE_STATE_TAG_OFFSET..]
        .try_into()
        .map_err(|_| DeviceCryptoError::DeviceStateAuthenticationFailed)?;
    cipher
        .decrypt_inout_detached(
            &nonce,
            &blob.0[..DEVICE_STATE_CIPHERTEXT_OFFSET],
            plaintext.as_mut_slice().into(),
            tag,
        )
        .map_err(|_| DeviceCryptoError::DeviceStateAuthenticationFailed)?;

    // 元数据与秘密使用同一 AEAD tag；认证前不得把 clear metadata 提升为可信绑定。
    let binding = blob.authenticated_binding()?;

    let signing_seed = Zeroizing::new(copy_array(&plaintext[..DEVICE_PRIVATE_KEY_LENGTH]));
    let key_agreement_bytes = Zeroizing::new(copy_array(
        &plaintext[DEVICE_PRIVATE_KEY_LENGTH..DEVICE_PRIVATE_KEY_LENGTH * 2],
    ));
    let ark_bytes = Zeroizing::new(copy_array(&plaintext[DEVICE_PRIVATE_KEY_LENGTH * 2..]));
    let identity = DeviceIdentity::from_private_bytes(*signing_seed, *key_agreement_bytes)?;
    let ark = if binding.account.is_some() {
        Some(AccountRootKey::from_bytes(*ark_bytes))
    } else {
        if *ark_bytes != [0; ACCOUNT_ROOT_KEY_LENGTH] {
            return Err(DeviceCryptoError::DeviceStateAuthenticationFailed);
        }
        None
    };
    Ok((binding, identity, ark))
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
            attempt_id: DeviceProofAttemptId::new(uuid_v4(1)).expect("attempt UUID 应有效"),
            account_context_id: AccountContextId::new(uuid_v4(2)).expect("账户上下文 UUID 应有效"),
            device_id: DeviceId::new(uuid_v4(3)).expect("设备 UUID 应有效"),
            expires_at_ms: 1_800_000_000_000,
            challenge: DeviceProofChallenge::from_bytes([0x44; 32]),
            signing_public_key: signing_key.public_key(),
            key_agreement_public_key: agreement_key.public_key(),
            primary_payload_hash: Sha256Digest::of(b"OPAQUE finish"),
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
            attempt_id: DeviceProofAttemptId::new(uuid_v4(1)).expect("attempt UUID 应有效"),
            account_context_id: AccountContextId::new(uuid_v4(2)).expect("账户上下文 UUID 应有效"),
            device_id: DeviceId::new(uuid_v4(3)).expect("设备 UUID 应有效"),
            expires_at_ms: 1_800_000_000_000,
            challenge: DeviceProofChallenge::from_bytes([0x44; 32]),
            signing_public_key: signing_key.public_key(),
            key_agreement_public_key: agreement_key.public_key(),
            primary_payload_hash: Sha256Digest::of(b"OPAQUE finish"),
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
            fields.account_context_id.as_bytes()
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
            fields.primary_payload_hash.as_bytes()
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
            ("account context", PROOF_ACCOUNT_CONTEXT_OFFSET),
            ("device", PROOF_DEVICE_OFFSET),
            ("expires", PROOF_EXPIRES_OFFSET),
            ("challenge", PROOF_CHALLENGE_OFFSET),
            ("signing key", PROOF_SIGNING_KEY_OFFSET),
            ("key agreement", PROOF_KEY_AGREEMENT_OFFSET),
            ("primary payload hash", PROOF_PRIMARY_PAYLOAD_HASH_OFFSET),
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
    fn signing_public_key_rejects_cctv_mixed_order_point() {
        // CCTV #50 是可规范解码、非纯小阶但带低阶分量的 A，必须在导入边界拒绝。
        let mixed_order_key = hex_array::<DEVICE_PUBLIC_KEY_LENGTH>(
            "10eb7c3acfb2bed3e0d6ab89bf5a3d6afddd1176ce4812e38d9fd485058fdb1f",
        );
        let signature =
            Signature::from_bytes(&hex_array::<DEVICE_PROOF_SIGNATURE_LENGTH>(concat!(
                "b62cf890de42c413b11b1411c9f01f1c4d77aa87ef182258d1251f69af2a3506",
                "08f32d206a7c0b7efa9a59e66546e8f1f599ef843fb502c9cc3c4ae8b7c11e05",
            )));
        let dalek_key =
            VerifyingKey::from_bytes(&mixed_order_key).expect("CCTV #50 公钥应能被 dalek 2.2 解码");

        assert!(
            dalek_key
                .verify_strict(b"ed25519vectors 5", &signature)
                .is_ok()
        );

        assert!(matches!(
            DeviceSigningPublicKey::from_bytes(mixed_order_key),
            Err(DeviceCryptoError::InvalidSigningPublicKey)
        ));
    }

    #[test]
    fn device_signature_rejects_cctv_mixed_order_r() {
        // CCTV #7 的 A 与 R 都带低阶分量，dalek 2.2 严格验签仍接受该固定向量。
        let mixed_order_key = hex_array::<DEVICE_PUBLIC_KEY_LENGTH>(
            "10eb7c3acfb2bed3e0d6ab89bf5a3d6afddd1176ce4812e38d9fd485058fdb1f",
        );
        let signature =
            Signature::from_bytes(&hex_array::<DEVICE_PROOF_SIGNATURE_LENGTH>(concat!(
                "36684ea91032ba5b1dbab2d02f4debc74c3327f2b3802e2e4d371aa42b12b56b",
                "bbfd00bd9c259d8d222d15e67a3d8228585050dbb9b9585be20d8fadc721da03",
            )));
        let signature_bytes = signature.to_bytes();
        let signature_r = copy_array(&signature_bytes[..DEVICE_PUBLIC_KEY_LENGTH]);
        let dalek_key =
            VerifyingKey::from_bytes(&mixed_order_key).expect("CCTV #7 公钥应能被 dalek 2.2 解码");

        assert!(
            dalek_key
                .verify_strict(b"ed25519vectors", &signature)
                .is_ok()
        );
        assert!(!is_strict_ed25519_point(&signature_r));
        assert!(!verify_strict_device_signature(
            &dalek_key,
            b"ed25519vectors",
            &signature,
        ));
    }

    #[test]
    fn device_proof_rejects_stale_attempt_with_valid_signature() {
        let (expected_fields, _, _) = device_proof_fixture();
        let signing_key = DeviceSigningPrivateKey::from_seed([0x11; 32]);
        let mut stale_fields = expected_fields;
        stale_fields.attempt_id =
            DeviceProofAttemptId::new(uuid_v4(9)).expect("旧 attempt UUID 应有效");
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

    #[test]
    fn device_identity_signs_only_strict_raw_opaque_finish_payloads() {
        let identity =
            DeviceIdentity::from_private_bytes([0x11; 32], [0x22; 32]).expect("设备身份应可构造");
        let context = DeviceProofContext {
            attempt_id: DeviceProofAttemptId::new(uuid_v4(1)).expect("attempt UUID 应有效"),
            account_context_id: AccountContextId::new(uuid_v4(2)).expect("账户上下文 UUID 应有效"),
            device_id: DeviceId::new(uuid_v4(3)).expect("设备 UUID 应有效"),
            expires_at_ms: 1_800_000_000_000,
            challenge: DeviceProofChallenge::from_bytes([0x44; 32]),
        };
        let finalization = [0x55; crate::CREDENTIAL_FINALIZATION_LENGTH];
        let signature = identity
            .sign_opaque_finish_proof(DeviceProofKind::LoginFinish, context, &finalization, &[])
            .expect("严格登录完成载荷应可签名");
        let public_keys = identity.public_keys();
        let expected = DeviceProofFields {
            kind: DeviceProofKind::LoginFinish,
            attempt_id: context.attempt_id,
            account_context_id: context.account_context_id,
            device_id: context.device_id,
            expires_at_ms: context.expires_at_ms,
            challenge: context.challenge,
            signing_public_key: public_keys.signing,
            key_agreement_public_key: public_keys.key_agreement,
            primary_payload_hash: Sha256Digest::of(&finalization),
            envelope_hash: Sha256Digest::of(&[]),
        };
        DeviceProofMessage::new(expected)
            .expect("预期 KDPF 应可构造")
            .verify_expected(expected, &signature)
            .expect("签名必须覆盖 Rust 内部计算的原始载荷摘要");

        assert!(matches!(
            identity.sign_opaque_finish_proof(
                DeviceProofKind::LoginFinish,
                context,
                &finalization[..finalization.len() - 1],
                &[],
            ),
            Err(DeviceCryptoError::InvalidPrimaryPayloadLength { .. })
        ));
        assert!(matches!(
            identity.sign_opaque_finish_proof(
                DeviceProofKind::LoginFinish,
                context,
                &finalization,
                &[0],
            ),
            Err(DeviceCryptoError::InvalidEnvelopePayloadLength { .. })
        ));
        assert!(matches!(
            identity.sign_opaque_finish_proof(
                DeviceProofKind::PairingApprove,
                context,
                &[0; PAIRING_SECRET_LENGTH],
                &[0; ARK_ENVELOPE_LENGTH],
            ),
            Err(DeviceCryptoError::UnsupportedDeviceProofKind(3))
        ));
    }

    #[test]
    fn pairing_authenticator_is_the_first_trust_root_before_kdpf_and_kaek() {
        let issuer =
            DeviceIdentity::from_private_bytes([0x11; 32], [0x22; 32]).expect("签发设备身份应有效");
        let target =
            DeviceIdentity::from_private_bytes([0x33; 32], [0x44; 32]).expect("目标设备身份应有效");
        let ark = AccountRootKey::from_bytes([0x55; ACCOUNT_ROOT_KEY_LENGTH]);
        let user_id = UserId::new(uuid_v4(1)).expect("用户 UUID 应有效");
        let issuer_device_id = DeviceId::new(uuid_v4(2)).expect("签发设备 UUID 应有效");
        let target_device_id = DeviceId::new(uuid_v4(3)).expect("目标设备 UUID 应有效");
        let issuer_public_keys = issuer.public_keys();
        let target_public_keys = target.public_keys();
        let key_epoch = 7;
        let envelope = issuer
            .seal_ark_envelope(
                &mut TestRng(1),
                &ark,
                ArkEnvelopeBinding {
                    user_id,
                    issuer_device_id,
                    target_device_id,
                    key_epoch,
                    issuer_signing_public_key: issuer_public_keys.signing,
                    issuer_key_agreement_public_key: issuer_public_keys.key_agreement,
                    target_signing_public_key: target_public_keys.signing,
                    target_key_agreement_public_key: target_public_keys.key_agreement,
                },
            )
            .expect("配对 KAEK 应可密封");
        let pairing_id = DeviceProofAttemptId::new(uuid_v4(4)).expect("pairing UUID 应有效");
        let expires_at_ms = 1_800_000_000_000;
        let challenge = DeviceProofChallenge::from_bytes([0x66; 32]);
        let pairing_secret = [0x77; PAIRING_SECRET_LENGTH];
        let (signature, authenticator) = issuer
            .sign_pairing_approval_proof(
                DeviceProofContext {
                    attempt_id: pairing_id,
                    account_context_id: AccountContextId::new(*user_id.as_bytes())
                        .expect("用户 UUID 应可作为账户上下文"),
                    device_id: issuer_device_id,
                    expires_at_ms,
                    challenge,
                },
                &pairing_secret,
                &envelope,
            )
            .expect("配对批准应产生证明和认证器");
        assert_eq!(
            authenticator.as_bytes(),
            &hex_array::<PAIRING_AUTHENTICATOR_LENGTH>(
                "2b65a897a33efcf05dd529ce7c33a8f3269b1fded3404bd6ee283f1b08a5eceb"
            )
        );
        let expected = PairingApprovalExpected {
            pairing_id,
            user_id,
            issuer_device_id,
            target_device_id,
            expires_at_ms,
            challenge,
            key_epoch,
            issuer_public_keys,
        };
        let installed = target
            .open_pairing_approval(
                expected,
                &pairing_secret,
                signature.as_bytes(),
                authenticator.as_bytes(),
                envelope.as_bytes(),
            )
            .expect("认证器、KDPF 与 KAEK 全部有效后才应安装 ARK");
        assert_eq!(installed.0, ark.0);

        let assert_authenticator_rejected =
            |candidate_expected: PairingApprovalExpected,
             candidate_secret: &[u8],
             candidate_signature: &[u8],
             candidate_envelope: &[u8]| {
                assert!(matches!(
                    target.open_pairing_approval(
                        candidate_expected,
                        candidate_secret,
                        candidate_signature,
                        authenticator.as_bytes(),
                        candidate_envelope,
                    ),
                    Err(DeviceCryptoError::PairingAuthenticatorInvalid)
                ));
            };

        let mut wrong_secret = pairing_secret;
        wrong_secret[0] ^= 1;
        assert_authenticator_rejected(
            expected,
            &wrong_secret,
            signature.as_bytes(),
            envelope.as_bytes(),
        );

        let mut forged_signature = *signature.as_bytes();
        forged_signature[0] ^= 1;
        assert_authenticator_rejected(
            expected,
            &pairing_secret,
            &forged_signature,
            envelope.as_bytes(),
        );

        let mut forged_envelope = *envelope.as_bytes();
        forged_envelope[0] ^= 1;
        assert_authenticator_rejected(
            expected,
            &pairing_secret,
            signature.as_bytes(),
            &forged_envelope,
        );

        let mut changed = expected;
        changed.pairing_id =
            DeviceProofAttemptId::new(uuid_v4(5)).expect("替换 pairing UUID 应有效");
        assert_authenticator_rejected(
            changed,
            &pairing_secret,
            signature.as_bytes(),
            envelope.as_bytes(),
        );

        changed = expected;
        changed.user_id = UserId::new(uuid_v4(6)).expect("替换用户 UUID 应有效");
        assert_authenticator_rejected(
            changed,
            &pairing_secret,
            signature.as_bytes(),
            envelope.as_bytes(),
        );

        changed = expected;
        changed.issuer_device_id = DeviceId::new(uuid_v4(7)).expect("替换设备 UUID 应有效");
        assert_authenticator_rejected(
            changed,
            &pairing_secret,
            signature.as_bytes(),
            envelope.as_bytes(),
        );

        changed = expected;
        changed.expires_at_ms += 1;
        assert_authenticator_rejected(
            changed,
            &pairing_secret,
            signature.as_bytes(),
            envelope.as_bytes(),
        );

        changed = expected;
        changed.challenge = DeviceProofChallenge::from_bytes([0x67; 32]);
        assert_authenticator_rejected(
            changed,
            &pairing_secret,
            signature.as_bytes(),
            envelope.as_bytes(),
        );

        let alternate_issuer =
            DeviceIdentity::from_private_bytes([0x12; 32], [0x23; 32]).expect("替换签发身份应有效");
        let alternate_issuer_keys = alternate_issuer.public_keys();
        changed = expected;
        changed.issuer_public_keys.signing = alternate_issuer_keys.signing;
        assert_authenticator_rejected(
            changed,
            &pairing_secret,
            signature.as_bytes(),
            envelope.as_bytes(),
        );

        changed = expected;
        changed.issuer_public_keys.key_agreement = alternate_issuer_keys.key_agreement;
        assert_authenticator_rejected(
            changed,
            &pairing_secret,
            signature.as_bytes(),
            envelope.as_bytes(),
        );

        let mut forged_authenticator = *authenticator.as_bytes();
        forged_authenticator[0] ^= 1;
        assert!(matches!(
            target.open_pairing_approval(
                expected,
                &pairing_secret,
                signature.as_bytes(),
                &forged_authenticator,
                envelope.as_bytes(),
            ),
            Err(DeviceCryptoError::PairingAuthenticatorInvalid)
        ));

        let mut changed_target = expected;
        changed_target.target_device_id =
            DeviceId::new(uuid_v4(8)).expect("替换目标设备 UUID 应有效");
        assert!(matches!(
            target.open_pairing_approval(
                changed_target,
                &pairing_secret,
                signature.as_bytes(),
                authenticator.as_bytes(),
                envelope.as_bytes(),
            ),
            Err(DeviceCryptoError::ArkEnvelopeBindingMismatch)
        ));

        let mut newer_epoch = expected;
        newer_epoch.key_epoch += 1;
        assert!(matches!(
            target.open_pairing_approval(
                newer_epoch,
                &pairing_secret,
                signature.as_bytes(),
                authenticator.as_bytes(),
                envelope.as_bytes(),
            ),
            Err(DeviceCryptoError::ArkEnvelopeBindingMismatch)
        ));

        let wrong_target =
            DeviceIdentity::from_private_bytes([0x34; 32], [0x45; 32]).expect("替换目标身份应有效");
        assert!(matches!(
            wrong_target.open_pairing_approval(
                expected,
                &pairing_secret,
                signature.as_bytes(),
                authenticator.as_bytes(),
                envelope.as_bytes(),
            ),
            Err(DeviceCryptoError::ArkEnvelopeBindingMismatch)
        ));
    }

    #[test]
    fn device_state_supports_identity_only_then_ark_install_and_reseal() {
        let state_key = [0x91; DEVICE_STATE_KEY_LENGTH];
        let identity =
            DeviceIdentity::from_private_bytes([0x11; 32], [0x22; 32]).expect("设备身份应有效");
        let public_keys = identity.public_keys();
        let pending_binding = DeviceStateBinding {
            device_id: DeviceId::new(uuid_v4(1)).expect("设备 UUID 应有效"),
            key_version: 1,
            account: None,
        };
        let identity_only = seal_device_state(
            &mut TestRng(1),
            &state_key,
            &identity,
            None,
            pending_binding,
        )
        .expect("pending 身份应可单独密封");
        assert_eq!(identity_only.as_bytes().len(), DEVICE_STATE_BLOB_LENGTH);
        assert_eq!(
            u16::from_be_bytes(copy_array(&identity_only.as_bytes()[8..10])),
            0
        );
        let (reopened_binding, reopened_identity, reopened_ark) =
            open_device_state(&state_key, &identity_only).expect("pending 状态应可重开");
        assert_eq!(reopened_binding, pending_binding);
        assert_eq!(reopened_identity.public_keys(), public_keys);
        assert!(reopened_ark.is_none());

        let ark = AccountRootKey::from_bytes([0x55; ACCOUNT_ROOT_KEY_LENGTH]);
        let installed_binding = DeviceStateBinding {
            device_id: pending_binding.device_id,
            key_version: pending_binding.key_version,
            account: Some(DeviceStateAccountBinding {
                user_id: UserId::new(uuid_v4(2)).expect("用户 UUID 应有效"),
                key_epoch: 7,
            }),
        };
        let installed = seal_device_state(
            &mut TestRng(2),
            &state_key,
            &reopened_identity,
            Some(&ark),
            installed_binding,
        )
        .expect("安装 ARK 后应可重封");
        assert_eq!(
            u16::from_be_bytes(copy_array(&installed.as_bytes()[8..10])),
            DEVICE_STATE_FLAG_ARK_PRESENT
        );
        let (reopened_installed_binding, installed_identity, installed_ark) =
            open_device_state(&state_key, &installed).expect("完整状态应可重开");
        assert_eq!(reopened_installed_binding, installed_binding);
        assert_eq!(installed_identity.public_keys(), public_keys);
        assert_eq!(installed_ark.expect("完整状态必须产生 ARK").0, ark.0);

        let mut tampered = *installed.as_bytes();
        tampered[DEVICE_STATE_CIPHERTEXT_OFFSET] ^= 1;
        let tampered = DeviceStateBlob::from_bytes(&tampered).expect("篡改不破坏固定头格式");
        assert!(matches!(
            open_device_state(&state_key, &tampered),
            Err(DeviceCryptoError::DeviceStateAuthenticationFailed)
        ));

        let mut tampered_metadata = *installed.as_bytes();
        tampered_metadata[DEVICE_STATE_DEVICE_ID_OFFSET] ^= 1;
        let tampered_metadata = DeviceStateBlob::from_bytes(&tampered_metadata)
            .expect("明文元数据必须等到 AEAD 认证后解析");
        assert!(matches!(
            open_device_state(&state_key, &tampered_metadata),
            Err(DeviceCryptoError::DeviceStateAuthenticationFailed)
        ));
        assert!(matches!(
            open_device_state(&[0x92; DEVICE_STATE_KEY_LENGTH], &installed),
            Err(DeviceCryptoError::DeviceStateAuthenticationFailed)
        ));
    }
}
