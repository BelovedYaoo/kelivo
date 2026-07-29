//! 账户恢复 capsule 与独立口令恢复介质的唯一 v1 线格式。

use std::{convert::Infallible, fmt, str};

use chacha20poly1305::{
    Tag, XChaCha20Poly1305, XNonce,
    aead::{AeadInOut, KeyInit},
};
use hkdf::Hkdf;
use hpke::{
    Deserializable, Kem as HpkeKemTrait, OpModeR, OpModeS, Serializable,
    aead::{AeadTag, ChaCha20Poly1305 as HpkeAead},
    inout::InOutBuf,
    kdf::HkdfSha256 as HpkeKdf,
    kem::X25519HkdfSha256 as HpkeKem,
    setup_receiver, setup_sender_with_rng,
};
use opaque_ke::argon2::{Algorithm, Argon2, Params, Version};
use rand::{CryptoRng, RngCore};
use sha2_device::{Digest, Sha256};
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use crate::{
    ARGON2_ITERATIONS, ARGON2_MEMORY_KIB, ARGON2_PARALLELISM,
    device_crypto::{
        AccountRootKey, AccountTrustBinding, AccountTrustPublicKey, AccountTrustSignature,
        DeviceId, DeviceKeyAgreementPublicKey, DeviceSigningPublicKey, UserId,
        verify_account_trust_payload,
    },
};

const RECOVERY_CAPSULE_MAGIC: [u8; 8] = *b"KELVRCP1";
pub const RECOVERY_CAPSULE_VERSION: u16 = 1;
pub const RECOVERY_CAPSULE_SUITE_ID: u16 = 1;
const RECOVERY_CAPSULE_RESERVED: u32 = 0;
pub const RECOVERY_CAPSULE_HEADER_LENGTH: usize = 76;
pub const RECOVERY_PUBLIC_KEY_LENGTH: usize = 32;
pub const RECOVERY_PRIVATE_KEY_LENGTH: usize = 32;
pub const RECOVERY_CAPSULE_ENCAPSULATED_KEY_LENGTH: usize = 32;
pub const RECOVERY_CAPSULE_CIPHERTEXT_LENGTH: usize = 32;
pub const RECOVERY_CAPSULE_TAG_LENGTH: usize = 16;
pub const RECOVERY_CAPSULE_LENGTH: usize = 156;
const RECOVERY_CAPSULE_INFO_DOMAIN: &[u8] = b"kelivo.recovery-capsule.hpke-info.v1";

const RECOVERY_MEDIA_MAGIC: [u8; 8] = *b"KELVRM01";
pub const RECOVERY_MEDIA_VERSION: u16 = 1;
pub const RECOVERY_MEDIA_SUITE_ID: u16 = 1;
pub const RECOVERY_MEDIA_KDF_PROFILE_ID: u16 = 1;
const RECOVERY_MEDIA_FLAGS: u16 = 0;
pub const RECOVERY_MEDIA_HEADER_LENGTH: usize = 96;
pub const RECOVERY_MEDIA_PLAINTEXT_LENGTH: usize = 532;
pub const RECOVERY_MEDIA_SALT_LENGTH: usize = 16;
pub const RECOVERY_MEDIA_NONCE_LENGTH: usize = 24;
pub const RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH: usize = 32;
pub const RECOVERY_GENESIS_LENGTH: usize = 444;
pub const RECOVERY_MEDIA_TAG_LENGTH: usize = 16;
pub const RECOVERY_MEDIA_LENGTH: usize = 644;
pub const RECOVERY_PASSPHRASE_MIN_SCALARS: usize = 12;
pub const RECOVERY_PASSPHRASE_MAX_UTF8_LENGTH: usize = 128;
const RECOVERY_MEDIA_WRAP_KEY_INFO: &[u8] = b"kelivo.recovery-media.wrap-key.v1";
const RECOVERY_MEDIA_KEY_LENGTH: usize = 32;

const CAPSULE_USER_ID_OFFSET: usize = 16;
const CAPSULE_KEY_EPOCH_OFFSET: usize = 32;
const CAPSULE_PUBLIC_KEY_VERSION_OFFSET: usize = 36;
const CAPSULE_VERSION_OFFSET: usize = 40;
const CAPSULE_PUBLIC_KEY_OFFSET: usize = 44;
const CAPSULE_ENCAPSULATED_KEY_OFFSET: usize = RECOVERY_CAPSULE_HEADER_LENGTH;
const CAPSULE_CIPHERTEXT_OFFSET: usize =
    CAPSULE_ENCAPSULATED_KEY_OFFSET + RECOVERY_CAPSULE_ENCAPSULATED_KEY_LENGTH;
const CAPSULE_TAG_OFFSET: usize = CAPSULE_CIPHERTEXT_OFFSET + RECOVERY_CAPSULE_CIPHERTEXT_LENGTH;

const MEDIA_SALT_OFFSET: usize = 24;
const MEDIA_NONCE_OFFSET: usize = MEDIA_SALT_OFFSET + RECOVERY_MEDIA_SALT_LENGTH;
const MEDIA_ORIGIN_OFFSET: usize = MEDIA_NONCE_OFFSET + RECOVERY_MEDIA_NONCE_LENGTH;
const MEDIA_CIPHERTEXT_OFFSET: usize = RECOVERY_MEDIA_HEADER_LENGTH;
const MEDIA_TAG_OFFSET: usize = MEDIA_CIPHERTEXT_OFFSET + RECOVERY_MEDIA_PLAINTEXT_LENGTH;

const MEDIA_PLAINTEXT_PUBLIC_KEY_VERSION_OFFSET: usize = 16;
const MEDIA_PLAINTEXT_PRIVATE_KEY_OFFSET: usize = 20;
const MEDIA_PLAINTEXT_GENESIS_LENGTH_OFFSET: usize = 52;
const MEDIA_PLAINTEXT_GENESIS_DIGEST_OFFSET: usize = 56;
const MEDIA_PLAINTEXT_GENESIS_OFFSET: usize = 88;

const GENESIS_PAYLOAD_LENGTH: usize = 316;
const GENESIS_TRANSITION_SIGNATURE_OFFSET: usize = GENESIS_PAYLOAD_LENGTH;
const GENESIS_CURRENT_SIGNATURE_OFFSET: usize = GENESIS_TRANSITION_SIGNATURE_OFFSET + 64;

const _: () = {
    assert!(
        CAPSULE_PUBLIC_KEY_OFFSET + RECOVERY_PUBLIC_KEY_LENGTH == RECOVERY_CAPSULE_HEADER_LENGTH
    );
    assert!(CAPSULE_TAG_OFFSET + RECOVERY_CAPSULE_TAG_LENGTH == RECOVERY_CAPSULE_LENGTH);
    assert!(
        MEDIA_ORIGIN_OFFSET + RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH == RECOVERY_MEDIA_HEADER_LENGTH
    );
    assert!(MEDIA_TAG_OFFSET + RECOVERY_MEDIA_TAG_LENGTH == RECOVERY_MEDIA_LENGTH);
    assert!(
        MEDIA_PLAINTEXT_GENESIS_OFFSET + RECOVERY_GENESIS_LENGTH == RECOVERY_MEDIA_PLAINTEXT_LENGTH
    );
    assert!(GENESIS_CURRENT_SIGNATURE_OFFSET + 64 == RECOVERY_GENESIS_LENGTH);
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RecoveryCryptoError {
    InvalidUserId,
    InvalidPositiveVersion,
    InvalidRecoveryPublicKey,
    InvalidRecoveryPrivateKey,
    RecoveryKeyMismatch,
    RandomnessUnavailable,
    InvalidPassphraseUtf8,
    PassphraseTooShort,
    PassphraseTooLong,
    InvalidCapsuleLength { expected: usize, actual: usize },
    InvalidCapsuleMagic,
    UnsupportedCapsuleVersion(u16),
    UnsupportedCapsuleSuite(u16),
    UnsupportedCapsuleReserved(u32),
    CapsuleSealFailed,
    CapsuleOpenFailed,
    InvalidMediaLength { expected: usize, actual: usize },
    InvalidMediaMagic,
    UnsupportedMediaVersion(u16),
    UnsupportedMediaSuite(u16),
    UnsupportedMediaKdfProfile(u16),
    UnsupportedMediaFlags(u16),
    InvalidMediaDeclaredLength(u32),
    InvalidMediaPlaintextLength(u32),
    MediaOriginMismatch,
    MediaKdfFailed,
    MediaSealFailed,
    MediaAuthenticationFailed,
    InvalidGenesis,
    GenesisDigestMismatch,
    GenesisSignatureInvalid,
}

impl fmt::Display for RecoveryCryptoError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidUserId => formatter.write_str("恢复账户标识无效"),
            Self::InvalidPositiveVersion => formatter.write_str("恢复版本必须为正整数"),
            Self::InvalidRecoveryPublicKey => formatter.write_str("恢复公钥无效"),
            Self::InvalidRecoveryPrivateKey => formatter.write_str("恢复私钥无效"),
            Self::RecoveryKeyMismatch => formatter.write_str("恢复公私钥或 genesis 绑定不一致"),
            Self::RandomnessUnavailable => formatter.write_str("恢复协议随机源不可用"),
            Self::InvalidPassphraseUtf8 => formatter.write_str("恢复口令不是有效 UTF-8"),
            Self::PassphraseTooShort => formatter.write_str("恢复口令少于 12 个 Unicode scalar"),
            Self::PassphraseTooLong => formatter.write_str("恢复口令超过 128 个 UTF-8 字节"),
            Self::InvalidCapsuleLength { expected, actual } => write!(
                formatter,
                "恢复 capsule 长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::InvalidCapsuleMagic => formatter.write_str("恢复 capsule 魔数无效"),
            Self::UnsupportedCapsuleVersion(version) => {
                write!(formatter, "不支持的恢复 capsule 版本：{version}")
            }
            Self::UnsupportedCapsuleSuite(suite) => {
                write!(formatter, "不支持的恢复 capsule 套件：{suite}")
            }
            Self::UnsupportedCapsuleReserved(value) => {
                write!(formatter, "恢复 capsule 保留字段必须为零，实际 {value}")
            }
            Self::CapsuleSealFailed => formatter.write_str("恢复 capsule 密封失败"),
            Self::CapsuleOpenFailed => formatter.write_str("恢复 capsule 认证或解密失败"),
            Self::InvalidMediaLength { expected, actual } => write!(
                formatter,
                "恢复介质长度无效，预期 {expected}，实际 {actual}"
            ),
            Self::InvalidMediaMagic => formatter.write_str("恢复介质魔数无效"),
            Self::UnsupportedMediaVersion(version) => {
                write!(formatter, "不支持的恢复介质版本：{version}")
            }
            Self::UnsupportedMediaSuite(suite) => {
                write!(formatter, "不支持的恢复介质套件：{suite}")
            }
            Self::UnsupportedMediaKdfProfile(profile) => {
                write!(formatter, "不支持的恢复介质 KDF profile：{profile}")
            }
            Self::UnsupportedMediaFlags(flags) => {
                write!(formatter, "恢复介质包含不支持的 flags：{flags}")
            }
            Self::InvalidMediaDeclaredLength(length) => {
                write!(formatter, "恢复介质声明总长度无效：{length}")
            }
            Self::InvalidMediaPlaintextLength(length) => {
                write!(formatter, "恢复介质声明明文长度无效：{length}")
            }
            Self::MediaOriginMismatch => formatter.write_str("恢复介质服务源绑定不匹配"),
            Self::MediaKdfFailed => formatter.write_str("恢复介质口令密钥派生失败"),
            Self::MediaSealFailed => formatter.write_str("恢复介质密封失败"),
            Self::MediaAuthenticationFailed => formatter.write_str("恢复介质口令或认证信息无效"),
            Self::InvalidGenesis => formatter.write_str("恢复介质 genesis 清单无效"),
            Self::GenesisDigestMismatch => formatter.write_str("恢复介质 genesis 摘要不匹配"),
            Self::GenesisSignatureInvalid => formatter.write_str("恢复介质 genesis 签名无效"),
        }
    }
}

impl std::error::Error for RecoveryCryptoError {}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct RecoveryPublicKey([u8; RECOVERY_PUBLIC_KEY_LENGTH]);

impl RecoveryPublicKey {
    pub fn from_bytes(
        bytes: [u8; RECOVERY_PUBLIC_KEY_LENGTH],
    ) -> Result<Self, RecoveryCryptoError> {
        <<HpkeKem as HpkeKemTrait>::PublicKey as Deserializable>::from_bytes(&bytes)
            .map_err(|_| RecoveryCryptoError::InvalidRecoveryPublicKey)?;
        Ok(Self(bytes))
    }

    pub const fn as_bytes(&self) -> &[u8; RECOVERY_PUBLIC_KEY_LENGTH] {
        &self.0
    }

    fn hpke_public_key(&self) -> Result<<HpkeKem as HpkeKemTrait>::PublicKey, RecoveryCryptoError> {
        <<HpkeKem as HpkeKemTrait>::PublicKey as Deserializable>::from_bytes(&self.0)
            .map_err(|_| RecoveryCryptoError::InvalidRecoveryPublicKey)
    }
}

pub struct RecoveryIdentity {
    private_key: [u8; RECOVERY_PRIVATE_KEY_LENGTH],
}

impl RecoveryIdentity {
    pub fn generate<R>(rng: &mut R) -> Result<Self, RecoveryCryptoError>
    where
        R: CryptoRng + RngCore,
    {
        let mut private_key = Zeroizing::new([0_u8; RECOVERY_PRIVATE_KEY_LENGTH]);
        rng.try_fill_bytes(private_key.as_mut_slice())
            .map_err(|_| RecoveryCryptoError::RandomnessUnavailable)?;
        Self::from_private_bytes(*private_key)
    }

    pub fn from_private_bytes(
        bytes: [u8; RECOVERY_PRIVATE_KEY_LENGTH],
    ) -> Result<Self, RecoveryCryptoError> {
        let bytes = Zeroizing::new(bytes);
        <<HpkeKem as HpkeKemTrait>::PrivateKey as Deserializable>::from_bytes(bytes.as_slice())
            .map_err(|_| RecoveryCryptoError::InvalidRecoveryPrivateKey)?;
        Ok(Self {
            private_key: *bytes,
        })
    }

    pub fn public_key(&self) -> Result<RecoveryPublicKey, RecoveryCryptoError> {
        let private_key = self.hpke_private_key()?;
        let public_key = HpkeKem::sk_to_pk(&private_key);
        RecoveryPublicKey::from_bytes(public_key.to_bytes().into())
    }

    fn hpke_private_key(
        &self,
    ) -> Result<<HpkeKem as HpkeKemTrait>::PrivateKey, RecoveryCryptoError> {
        <<HpkeKem as HpkeKemTrait>::PrivateKey as Deserializable>::from_bytes(&self.private_key)
            .map_err(|_| RecoveryCryptoError::InvalidRecoveryPrivateKey)
    }
}

impl Zeroize for RecoveryIdentity {
    fn zeroize(&mut self) {
        self.private_key.zeroize();
    }
}

impl ZeroizeOnDrop for RecoveryIdentity {}

impl Drop for RecoveryIdentity {
    fn drop(&mut self) {
        self.zeroize();
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RecoveryGenesisCapability([u8; RECOVERY_GENESIS_LENGTH]);

impl RecoveryGenesisCapability {
    pub const fn as_bytes(&self) -> &[u8; RECOVERY_GENESIS_LENGTH] {
        &self.0
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RecoveryCapsule([u8; RECOVERY_CAPSULE_LENGTH]);

impl RecoveryCapsule {
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, RecoveryCryptoError> {
        parse_capsule_header(bytes)?;
        <<HpkeKem as HpkeKemTrait>::EncappedKey as Deserializable>::from_bytes(
            &bytes[CAPSULE_ENCAPSULATED_KEY_OFFSET..CAPSULE_CIPHERTEXT_OFFSET],
        )
        .map_err(|_| RecoveryCryptoError::CapsuleOpenFailed)?;
        Ok(Self(copy_array(bytes)))
    }

    pub const fn as_bytes(&self) -> &[u8; RECOVERY_CAPSULE_LENGTH] {
        &self.0
    }

    pub fn user_id(&self) -> Result<UserId, RecoveryCryptoError> {
        UserId::new(copy_array(
            &self.0[CAPSULE_USER_ID_OFFSET..CAPSULE_KEY_EPOCH_OFFSET],
        ))
        .map_err(|_| RecoveryCryptoError::InvalidUserId)
    }

    pub fn key_epoch(&self) -> u32 {
        read_u32(&self.0, CAPSULE_KEY_EPOCH_OFFSET)
    }

    pub fn recovery_public_key_version(&self) -> u32 {
        read_u32(&self.0, CAPSULE_PUBLIC_KEY_VERSION_OFFSET)
    }

    pub fn capsule_version(&self) -> u32 {
        read_u32(&self.0, CAPSULE_VERSION_OFFSET)
    }

    pub fn recovery_public_key(&self) -> Result<RecoveryPublicKey, RecoveryCryptoError> {
        RecoveryPublicKey::from_bytes(copy_array(
            &self.0[CAPSULE_PUBLIC_KEY_OFFSET..CAPSULE_ENCAPSULATED_KEY_OFFSET],
        ))
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RecoveryMedia([u8; RECOVERY_MEDIA_LENGTH]);

impl RecoveryMedia {
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, RecoveryCryptoError> {
        parse_media_header(bytes)?;
        Ok(Self(copy_array(bytes)))
    }

    pub const fn as_bytes(&self) -> &[u8; RECOVERY_MEDIA_LENGTH] {
        &self.0
    }
}

pub struct ImportedRecovery {
    pub identity: RecoveryIdentity,
    pub user_id: UserId,
    pub recovery_public_key_version: u32,
    pub genesis: RecoveryGenesisCapability,
}

pub struct OpenedRecoveryCapsule {
    pub user_id: UserId,
    pub key_epoch: u32,
    pub capsule_version: u32,
    pub ark: AccountRootKey,
}

pub fn seal_recovery_capsule<R>(
    rng: &mut R,
    ark: &AccountRootKey,
    user_id: UserId,
    key_epoch: u32,
    recovery_public_key_version: u32,
    capsule_version: u32,
    recovery_public_key: RecoveryPublicKey,
) -> Result<RecoveryCapsule, RecoveryCryptoError>
where
    R: CryptoRng + RngCore,
{
    require_positive(key_epoch)?;
    require_positive(recovery_public_key_version)?;
    require_positive(capsule_version)?;
    let header = encode_capsule_header(
        user_id,
        key_epoch,
        recovery_public_key_version,
        capsule_version,
        recovery_public_key,
    );
    let info = capsule_info(&header);
    let public_key = recovery_public_key.hpke_public_key()?;
    let mut rng = HpkeRngAdapter(rng);
    let (encapsulated_key, mut sender_context) =
        setup_sender_with_rng::<HpkeAead, HpkeKdf, HpkeKem>(
            &OpModeS::Base,
            &public_key,
            &info,
            &mut rng,
        )
        .map_err(|_| RecoveryCryptoError::CapsuleSealFailed)?;
    let mut encrypted_ark = Zeroizing::new(*ark.as_bytes());
    let tag = sender_context
        .seal_inout_detached(InOutBuf::from(encrypted_ark.as_mut_slice()), &header)
        .map_err(|_| RecoveryCryptoError::CapsuleSealFailed)?;

    let mut bytes = [0_u8; RECOVERY_CAPSULE_LENGTH];
    bytes[..RECOVERY_CAPSULE_HEADER_LENGTH].copy_from_slice(&header);
    bytes[CAPSULE_ENCAPSULATED_KEY_OFFSET..CAPSULE_CIPHERTEXT_OFFSET]
        .copy_from_slice(encapsulated_key.to_bytes().as_slice());
    bytes[CAPSULE_CIPHERTEXT_OFFSET..CAPSULE_TAG_OFFSET].copy_from_slice(encrypted_ark.as_slice());
    bytes[CAPSULE_TAG_OFFSET..].copy_from_slice(tag.to_bytes().as_slice());
    Ok(RecoveryCapsule(bytes))
}

pub fn open_recovery_capsule(
    identity: &RecoveryIdentity,
    expected_user_id: UserId,
    expected_recovery_public_key_version: u32,
    capsule: &RecoveryCapsule,
) -> Result<OpenedRecoveryCapsule, RecoveryCryptoError> {
    require_positive(expected_recovery_public_key_version)?;
    let user_id = capsule.user_id()?;
    let recovery_public_key = capsule.recovery_public_key()?;
    if user_id != expected_user_id
        || capsule.recovery_public_key_version() != expected_recovery_public_key_version
        || recovery_public_key != identity.public_key()?
    {
        return Err(RecoveryCryptoError::RecoveryKeyMismatch);
    }

    let header: [u8; RECOVERY_CAPSULE_HEADER_LENGTH] =
        copy_array(&capsule.0[..RECOVERY_CAPSULE_HEADER_LENGTH]);
    let info = capsule_info(&header);
    let private_key = identity.hpke_private_key()?;
    let encapsulated_key = <<HpkeKem as HpkeKemTrait>::EncappedKey as Deserializable>::from_bytes(
        &capsule.0[CAPSULE_ENCAPSULATED_KEY_OFFSET..CAPSULE_CIPHERTEXT_OFFSET],
    )
    .map_err(|_| RecoveryCryptoError::CapsuleOpenFailed)?;
    let mut receiver_context = setup_receiver::<HpkeAead, HpkeKdf, HpkeKem>(
        &OpModeR::Base,
        &private_key,
        &encapsulated_key,
        &info,
    )
    .map_err(|_| RecoveryCryptoError::CapsuleOpenFailed)?;
    let mut plaintext = Zeroizing::new(copy_array(
        &capsule.0[CAPSULE_CIPHERTEXT_OFFSET..CAPSULE_TAG_OFFSET],
    ));
    let tag = AeadTag::<HpkeAead>::from_bytes(&capsule.0[CAPSULE_TAG_OFFSET..])
        .map_err(|_| RecoveryCryptoError::CapsuleOpenFailed)?;
    receiver_context
        .open_inout_detached(InOutBuf::from(plaintext.as_mut_slice()), &header, &tag)
        .map_err(|_| RecoveryCryptoError::CapsuleOpenFailed)?;

    Ok(OpenedRecoveryCapsule {
        user_id,
        key_epoch: capsule.key_epoch(),
        capsule_version: capsule.capsule_version(),
        ark: AccountRootKey::from_bytes(*plaintext),
    })
}

pub fn seal_recovery_media<R>(
    rng: &mut R,
    identity: &RecoveryIdentity,
    user_id: UserId,
    recovery_public_key_version: u32,
    genesis: &[u8],
    passphrase: &[u8],
    service_origin_sha256: &[u8; RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH],
) -> Result<RecoveryMedia, RecoveryCryptoError>
where
    R: CryptoRng + RngCore,
{
    require_positive(recovery_public_key_version)?;
    validate_passphrase(passphrase)?;
    let recovery_public_key = identity.public_key()?;
    let capability = validate_genesis(
        genesis,
        user_id,
        recovery_public_key_version,
        recovery_public_key,
    )?;

    let mut bytes = [0_u8; RECOVERY_MEDIA_LENGTH];
    encode_media_header(&mut bytes[..RECOVERY_MEDIA_HEADER_LENGTH]);
    rng.try_fill_bytes(&mut bytes[MEDIA_SALT_OFFSET..MEDIA_NONCE_OFFSET])
        .map_err(|_| RecoveryCryptoError::RandomnessUnavailable)?;
    rng.try_fill_bytes(&mut bytes[MEDIA_NONCE_OFFSET..MEDIA_ORIGIN_OFFSET])
        .map_err(|_| RecoveryCryptoError::RandomnessUnavailable)?;
    bytes[MEDIA_ORIGIN_OFFSET..MEDIA_CIPHERTEXT_OFFSET].copy_from_slice(service_origin_sha256);

    let mut plaintext = Zeroizing::new([0_u8; RECOVERY_MEDIA_PLAINTEXT_LENGTH]);
    plaintext[..MEDIA_PLAINTEXT_PUBLIC_KEY_VERSION_OFFSET].copy_from_slice(user_id.as_bytes());
    plaintext[MEDIA_PLAINTEXT_PUBLIC_KEY_VERSION_OFFSET..MEDIA_PLAINTEXT_PRIVATE_KEY_OFFSET]
        .copy_from_slice(&recovery_public_key_version.to_be_bytes());
    plaintext[MEDIA_PLAINTEXT_PRIVATE_KEY_OFFSET..MEDIA_PLAINTEXT_GENESIS_LENGTH_OFFSET]
        .copy_from_slice(&identity.private_key);
    plaintext[MEDIA_PLAINTEXT_GENESIS_LENGTH_OFFSET..MEDIA_PLAINTEXT_GENESIS_DIGEST_OFFSET]
        .copy_from_slice(&(RECOVERY_GENESIS_LENGTH as u32).to_be_bytes());
    let genesis_digest = Sha256::digest(capability.as_bytes());
    plaintext[MEDIA_PLAINTEXT_GENESIS_DIGEST_OFFSET..MEDIA_PLAINTEXT_GENESIS_OFFSET]
        .copy_from_slice(&genesis_digest);
    plaintext[MEDIA_PLAINTEXT_GENESIS_OFFSET..].copy_from_slice(capability.as_bytes());

    let key = derive_media_key(passphrase, &bytes[MEDIA_SALT_OFFSET..MEDIA_NONCE_OFFSET])?;
    let cipher = XChaCha20Poly1305::new_from_slice(key.as_slice())
        .map_err(|_| RecoveryCryptoError::MediaSealFailed)?;
    let nonce = XNonce::from(copy_array(&bytes[MEDIA_NONCE_OFFSET..MEDIA_ORIGIN_OFFSET]));
    let tag = cipher
        .encrypt_inout_detached(
            &nonce,
            &bytes[..RECOVERY_MEDIA_HEADER_LENGTH],
            plaintext.as_mut_slice().into(),
        )
        .map_err(|_| RecoveryCryptoError::MediaSealFailed)?;
    bytes[MEDIA_CIPHERTEXT_OFFSET..MEDIA_TAG_OFFSET].copy_from_slice(plaintext.as_slice());
    bytes[MEDIA_TAG_OFFSET..].copy_from_slice(tag.as_slice());
    Ok(RecoveryMedia(bytes))
}

pub fn open_recovery_media(
    media: &RecoveryMedia,
    passphrase: &[u8],
    expected_service_origin_sha256: &[u8; RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH],
) -> Result<ImportedRecovery, RecoveryCryptoError> {
    validate_passphrase(passphrase)?;
    if !same_bytes(
        &media.0[MEDIA_ORIGIN_OFFSET..MEDIA_CIPHERTEXT_OFFSET],
        expected_service_origin_sha256,
    ) {
        return Err(RecoveryCryptoError::MediaOriginMismatch);
    }
    let key = derive_media_key(passphrase, &media.0[MEDIA_SALT_OFFSET..MEDIA_NONCE_OFFSET])?;
    let cipher = XChaCha20Poly1305::new_from_slice(key.as_slice())
        .map_err(|_| RecoveryCryptoError::MediaAuthenticationFailed)?;
    let nonce = XNonce::from(copy_array(
        &media.0[MEDIA_NONCE_OFFSET..MEDIA_ORIGIN_OFFSET],
    ));
    let mut plaintext: Zeroizing<[u8; RECOVERY_MEDIA_PLAINTEXT_LENGTH]> = Zeroizing::new(
        copy_array(&media.0[MEDIA_CIPHERTEXT_OFFSET..MEDIA_TAG_OFFSET]),
    );
    let tag: &Tag = media.0[MEDIA_TAG_OFFSET..]
        .try_into()
        .map_err(|_| RecoveryCryptoError::MediaAuthenticationFailed)?;
    cipher
        .decrypt_inout_detached(
            &nonce,
            &media.0[..RECOVERY_MEDIA_HEADER_LENGTH],
            plaintext.as_mut_slice().into(),
            tag,
        )
        .map_err(|_| RecoveryCryptoError::MediaAuthenticationFailed)?;

    let user_id = UserId::new(copy_array(
        &plaintext[..MEDIA_PLAINTEXT_PUBLIC_KEY_VERSION_OFFSET],
    ))
    .map_err(|_| RecoveryCryptoError::InvalidGenesis)?;
    let recovery_public_key_version = read_u32(
        plaintext.as_slice(),
        MEDIA_PLAINTEXT_PUBLIC_KEY_VERSION_OFFSET,
    );
    require_positive(recovery_public_key_version)?;
    if read_u32(plaintext.as_slice(), MEDIA_PLAINTEXT_GENESIS_LENGTH_OFFSET)
        != RECOVERY_GENESIS_LENGTH as u32
    {
        return Err(RecoveryCryptoError::InvalidGenesis);
    }
    let genesis: [u8; RECOVERY_GENESIS_LENGTH] =
        copy_array(&plaintext[MEDIA_PLAINTEXT_GENESIS_OFFSET..]);
    let actual_digest = Sha256::digest(genesis);
    if !same_bytes(
        &plaintext[MEDIA_PLAINTEXT_GENESIS_DIGEST_OFFSET..MEDIA_PLAINTEXT_GENESIS_OFFSET],
        &actual_digest,
    ) {
        return Err(RecoveryCryptoError::GenesisDigestMismatch);
    }
    let identity = RecoveryIdentity::from_private_bytes(copy_array(
        &plaintext[MEDIA_PLAINTEXT_PRIVATE_KEY_OFFSET..MEDIA_PLAINTEXT_GENESIS_LENGTH_OFFSET],
    ))?;
    let capability = validate_genesis(
        &genesis,
        user_id,
        recovery_public_key_version,
        identity.public_key()?,
    )?;
    Ok(ImportedRecovery {
        identity,
        user_id,
        recovery_public_key_version,
        genesis: capability,
    })
}

fn parse_capsule_header(bytes: &[u8]) -> Result<(), RecoveryCryptoError> {
    if bytes.len() != RECOVERY_CAPSULE_LENGTH {
        return Err(RecoveryCryptoError::InvalidCapsuleLength {
            expected: RECOVERY_CAPSULE_LENGTH,
            actual: bytes.len(),
        });
    }
    if bytes[..8] != RECOVERY_CAPSULE_MAGIC {
        return Err(RecoveryCryptoError::InvalidCapsuleMagic);
    }
    let version = read_u16(bytes, 8);
    if version != RECOVERY_CAPSULE_VERSION {
        return Err(RecoveryCryptoError::UnsupportedCapsuleVersion(version));
    }
    let suite = read_u16(bytes, 10);
    if suite != RECOVERY_CAPSULE_SUITE_ID {
        return Err(RecoveryCryptoError::UnsupportedCapsuleSuite(suite));
    }
    let reserved = read_u32(bytes, 12);
    if reserved != RECOVERY_CAPSULE_RESERVED {
        return Err(RecoveryCryptoError::UnsupportedCapsuleReserved(reserved));
    }
    UserId::new(copy_array(
        &bytes[CAPSULE_USER_ID_OFFSET..CAPSULE_KEY_EPOCH_OFFSET],
    ))
    .map_err(|_| RecoveryCryptoError::InvalidUserId)?;
    require_positive(read_u32(bytes, CAPSULE_KEY_EPOCH_OFFSET))?;
    require_positive(read_u32(bytes, CAPSULE_PUBLIC_KEY_VERSION_OFFSET))?;
    require_positive(read_u32(bytes, CAPSULE_VERSION_OFFSET))?;
    RecoveryPublicKey::from_bytes(copy_array(
        &bytes[CAPSULE_PUBLIC_KEY_OFFSET..CAPSULE_ENCAPSULATED_KEY_OFFSET],
    ))?;
    Ok(())
}

fn encode_capsule_header(
    user_id: UserId,
    key_epoch: u32,
    recovery_public_key_version: u32,
    capsule_version: u32,
    recovery_public_key: RecoveryPublicKey,
) -> [u8; RECOVERY_CAPSULE_HEADER_LENGTH] {
    let mut header = [0_u8; RECOVERY_CAPSULE_HEADER_LENGTH];
    header[..8].copy_from_slice(&RECOVERY_CAPSULE_MAGIC);
    header[8..10].copy_from_slice(&RECOVERY_CAPSULE_VERSION.to_be_bytes());
    header[10..12].copy_from_slice(&RECOVERY_CAPSULE_SUITE_ID.to_be_bytes());
    header[12..16].copy_from_slice(&RECOVERY_CAPSULE_RESERVED.to_be_bytes());
    header[CAPSULE_USER_ID_OFFSET..CAPSULE_KEY_EPOCH_OFFSET].copy_from_slice(user_id.as_bytes());
    header[CAPSULE_KEY_EPOCH_OFFSET..CAPSULE_PUBLIC_KEY_VERSION_OFFSET]
        .copy_from_slice(&key_epoch.to_be_bytes());
    header[CAPSULE_PUBLIC_KEY_VERSION_OFFSET..CAPSULE_VERSION_OFFSET]
        .copy_from_slice(&recovery_public_key_version.to_be_bytes());
    header[CAPSULE_VERSION_OFFSET..CAPSULE_PUBLIC_KEY_OFFSET]
        .copy_from_slice(&capsule_version.to_be_bytes());
    header[CAPSULE_PUBLIC_KEY_OFFSET..].copy_from_slice(recovery_public_key.as_bytes());
    header
}

fn capsule_info(header: &[u8; RECOVERY_CAPSULE_HEADER_LENGTH]) -> Vec<u8> {
    let mut info = Vec::with_capacity(RECOVERY_CAPSULE_INFO_DOMAIN.len() + header.len());
    info.extend_from_slice(RECOVERY_CAPSULE_INFO_DOMAIN);
    info.extend_from_slice(header);
    info
}

fn parse_media_header(bytes: &[u8]) -> Result<(), RecoveryCryptoError> {
    if bytes.len() != RECOVERY_MEDIA_LENGTH {
        return Err(RecoveryCryptoError::InvalidMediaLength {
            expected: RECOVERY_MEDIA_LENGTH,
            actual: bytes.len(),
        });
    }
    if bytes[..8] != RECOVERY_MEDIA_MAGIC {
        return Err(RecoveryCryptoError::InvalidMediaMagic);
    }
    let version = read_u16(bytes, 8);
    if version != RECOVERY_MEDIA_VERSION {
        return Err(RecoveryCryptoError::UnsupportedMediaVersion(version));
    }
    let suite = read_u16(bytes, 10);
    if suite != RECOVERY_MEDIA_SUITE_ID {
        return Err(RecoveryCryptoError::UnsupportedMediaSuite(suite));
    }
    let profile = read_u16(bytes, 12);
    if profile != RECOVERY_MEDIA_KDF_PROFILE_ID {
        return Err(RecoveryCryptoError::UnsupportedMediaKdfProfile(profile));
    }
    let flags = read_u16(bytes, 14);
    if flags != RECOVERY_MEDIA_FLAGS {
        return Err(RecoveryCryptoError::UnsupportedMediaFlags(flags));
    }
    let total_length = read_u32(bytes, 16);
    if total_length != RECOVERY_MEDIA_LENGTH as u32 {
        return Err(RecoveryCryptoError::InvalidMediaDeclaredLength(
            total_length,
        ));
    }
    let plaintext_length = read_u32(bytes, 20);
    if plaintext_length != RECOVERY_MEDIA_PLAINTEXT_LENGTH as u32 {
        return Err(RecoveryCryptoError::InvalidMediaPlaintextLength(
            plaintext_length,
        ));
    }
    Ok(())
}

fn encode_media_header(header: &mut [u8]) {
    debug_assert_eq!(header.len(), RECOVERY_MEDIA_HEADER_LENGTH);
    header[..8].copy_from_slice(&RECOVERY_MEDIA_MAGIC);
    header[8..10].copy_from_slice(&RECOVERY_MEDIA_VERSION.to_be_bytes());
    header[10..12].copy_from_slice(&RECOVERY_MEDIA_SUITE_ID.to_be_bytes());
    header[12..14].copy_from_slice(&RECOVERY_MEDIA_KDF_PROFILE_ID.to_be_bytes());
    header[14..16].copy_from_slice(&RECOVERY_MEDIA_FLAGS.to_be_bytes());
    header[16..20].copy_from_slice(&(RECOVERY_MEDIA_LENGTH as u32).to_be_bytes());
    header[20..24].copy_from_slice(&(RECOVERY_MEDIA_PLAINTEXT_LENGTH as u32).to_be_bytes());
}

fn derive_media_key(
    passphrase: &[u8],
    salt: &[u8],
) -> Result<Zeroizing<[u8; RECOVERY_MEDIA_KEY_LENGTH]>, RecoveryCryptoError> {
    validate_passphrase(passphrase)?;
    if salt.len() != RECOVERY_MEDIA_SALT_LENGTH {
        return Err(RecoveryCryptoError::MediaKdfFailed);
    }
    let params = Params::new(
        ARGON2_MEMORY_KIB,
        ARGON2_ITERATIONS,
        ARGON2_PARALLELISM,
        Some(RECOVERY_MEDIA_KEY_LENGTH),
    )
    .map_err(|_| RecoveryCryptoError::MediaKdfFailed)?;
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut intermediate = Zeroizing::new([0_u8; RECOVERY_MEDIA_KEY_LENGTH]);
    argon2
        .hash_password_into(passphrase, salt, intermediate.as_mut_slice())
        .map_err(|_| RecoveryCryptoError::MediaKdfFailed)?;
    let mut key = Zeroizing::new([0_u8; RECOVERY_MEDIA_KEY_LENGTH]);
    Hkdf::<Sha256>::new(None, intermediate.as_slice())
        .expand(RECOVERY_MEDIA_WRAP_KEY_INFO, key.as_mut_slice())
        .map_err(|_| RecoveryCryptoError::MediaKdfFailed)?;
    Ok(key)
}

fn validate_passphrase(passphrase: &[u8]) -> Result<(), RecoveryCryptoError> {
    if passphrase.len() > RECOVERY_PASSPHRASE_MAX_UTF8_LENGTH {
        return Err(RecoveryCryptoError::PassphraseTooLong);
    }
    let passphrase =
        str::from_utf8(passphrase).map_err(|_| RecoveryCryptoError::InvalidPassphraseUtf8)?;
    if passphrase.chars().count() < RECOVERY_PASSPHRASE_MIN_SCALARS {
        return Err(RecoveryCryptoError::PassphraseTooShort);
    }
    Ok(())
}

fn validate_genesis(
    genesis: &[u8],
    expected_user_id: UserId,
    expected_recovery_public_key_version: u32,
    expected_recovery_public_key: RecoveryPublicKey,
) -> Result<RecoveryGenesisCapability, RecoveryCryptoError> {
    if genesis.len() != RECOVERY_GENESIS_LENGTH
        || genesis[..8] != *b"KELIVOMM"
        || read_u32(genesis, 8) != 1
        || genesis[12..28] != *expected_user_id.as_bytes()
        || read_u32(genesis, 28) != 1
        || read_u32(genesis, 32) != 1
        || genesis[36..68].iter().any(|byte| *byte != 0)
        || read_u32(genesis, 100) != expected_recovery_public_key_version
        || genesis[104..136] != *expected_recovery_public_key.as_bytes()
        || read_u32(genesis, 136) != 1
        || read_u32(genesis, 172) != 1
        || read_u32(genesis, 224) != 1
        || genesis[192..208] != genesis[208..224]
        || genesis[208..224] != genesis[228..244]
        || read_u32(genesis, 244) == 0
        || read_u32(genesis, 244) > 0x7fff_ffff
        || read_u32(genesis, 248) != 0
        || genesis[GENESIS_TRANSITION_SIGNATURE_OFFSET..GENESIS_CURRENT_SIGNATURE_OFFSET]
            .iter()
            .any(|byte| *byte != 0)
    {
        return Err(RecoveryCryptoError::InvalidGenesis);
    }
    UserId::new(copy_array(&genesis[12..28])).map_err(|_| RecoveryCryptoError::InvalidGenesis)?;
    DeviceId::new(copy_array(&genesis[176..192]))
        .map_err(|_| RecoveryCryptoError::InvalidGenesis)?;
    DeviceId::new(copy_array(&genesis[192..208]))
        .map_err(|_| RecoveryCryptoError::InvalidGenesis)?;
    DeviceSigningPublicKey::from_bytes(copy_array(&genesis[252..284]))
        .map_err(|_| RecoveryCryptoError::InvalidGenesis)?;
    let member_key_agreement =
        DeviceKeyAgreementPublicKey::from_bytes(copy_array(&genesis[284..316]))
            .map_err(|_| RecoveryCryptoError::InvalidGenesis)?;
    if same_bytes(
        member_key_agreement.as_bytes(),
        expected_recovery_public_key.as_bytes(),
    ) {
        return Err(RecoveryCryptoError::InvalidGenesis);
    }
    let trust_public_key = AccountTrustPublicKey::from_bytes(copy_array(&genesis[68..100]))
        .map_err(|_| RecoveryCryptoError::InvalidGenesis)?;
    let signature = AccountTrustSignature::from_bytes(
        &genesis[GENESIS_CURRENT_SIGNATURE_OFFSET..RECOVERY_GENESIS_LENGTH],
    )
    .map_err(|_| RecoveryCryptoError::InvalidGenesis)?;
    verify_account_trust_payload(
        &trust_public_key,
        AccountTrustBinding {
            user_id: expected_user_id,
            key_epoch: 1,
        },
        &genesis[..GENESIS_PAYLOAD_LENGTH],
        &signature,
    )
    .map_err(|_| RecoveryCryptoError::GenesisSignatureInvalid)?;
    Ok(RecoveryGenesisCapability(copy_array(genesis)))
}

fn require_positive(value: u32) -> Result<(), RecoveryCryptoError> {
    if value == 0 {
        Err(RecoveryCryptoError::InvalidPositiveVersion)
    } else {
        Ok(())
    }
}

fn read_u16(bytes: &[u8], offset: usize) -> u16 {
    u16::from_be_bytes(copy_array(&bytes[offset..offset + 2]))
}

fn read_u32(bytes: &[u8], offset: usize) -> u32 {
    u32::from_be_bytes(copy_array(&bytes[offset..offset + 4]))
}

fn same_bytes(left: &[u8], right: &[u8]) -> bool {
    left.len() == right.len()
        && left
            .iter()
            .zip(right)
            .fold(0_u8, |difference, (left, right)| {
                difference | (left ^ right)
            })
            == 0
}

fn copy_array<const LENGTH: usize>(bytes: &[u8]) -> [u8; LENGTH] {
    let mut output = [0_u8; LENGTH];
    output.copy_from_slice(bytes);
    output
}

struct HpkeRngAdapter<'a, R>(&'a mut R);

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::device_crypto::{
        AccountTrustBinding, DeviceIdentity, derive_account_trust_public_key,
        sign_account_trust_payload,
    };

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
                self.0 = self.0.wrapping_mul(73).wrapping_add(41);
                *byte = self.0;
            }
        }

        fn try_fill_bytes(&mut self, destination: &mut [u8]) -> Result<(), rand::Error> {
            self.fill_bytes(destination);
            Ok(())
        }
    }

    impl CryptoRng for TestRng {}

    fn uuid(seed: u8) -> [u8; 16] {
        let mut bytes = [seed; 16];
        bytes[6] = (bytes[6] & 0x0f) | 0x40;
        bytes[8] = (bytes[8] & 0x3f) | 0x80;
        bytes
    }

    fn genesis(
        ark: &AccountRootKey,
        user_id: UserId,
        recovery_public_key: RecoveryPublicKey,
        capsule: &RecoveryCapsule,
    ) -> [u8; RECOVERY_GENESIS_LENGTH] {
        let member = DeviceIdentity::generate(&mut TestRng(0x31)).expect("设备身份应生成");
        let member_public = member.public_keys();
        let binding = AccountTrustBinding {
            user_id,
            key_epoch: 1,
        };
        let trust_public = derive_account_trust_public_key(ark, binding).expect("信任公钥应派生");
        let operation_id = uuid(0x52);
        let device_id = uuid(0x53);
        let mut bytes = [0_u8; RECOVERY_GENESIS_LENGTH];
        bytes[..8].copy_from_slice(b"KELIVOMM");
        bytes[8..12].copy_from_slice(&1_u32.to_be_bytes());
        bytes[12..28].copy_from_slice(user_id.as_bytes());
        bytes[28..32].copy_from_slice(&1_u32.to_be_bytes());
        bytes[32..36].copy_from_slice(&1_u32.to_be_bytes());
        bytes[68..100].copy_from_slice(trust_public.as_bytes());
        bytes[100..104].copy_from_slice(&1_u32.to_be_bytes());
        bytes[104..136].copy_from_slice(recovery_public_key.as_bytes());
        bytes[136..140].copy_from_slice(&1_u32.to_be_bytes());
        bytes[140..172].copy_from_slice(&Sha256::digest(capsule.as_bytes()));
        bytes[172..176].copy_from_slice(&1_u32.to_be_bytes());
        bytes[176..192].copy_from_slice(&operation_id);
        bytes[192..208].copy_from_slice(&device_id);
        bytes[208..224].copy_from_slice(&device_id);
        bytes[224..228].copy_from_slice(&1_u32.to_be_bytes());
        bytes[228..244].copy_from_slice(&device_id);
        bytes[244..248].copy_from_slice(&1_u32.to_be_bytes());
        bytes[252..284].copy_from_slice(member_public.signing.as_bytes());
        bytes[284..316].copy_from_slice(member_public.key_agreement.as_bytes());
        let signature = sign_account_trust_payload(ark, binding, &bytes[..GENESIS_PAYLOAD_LENGTH])
            .expect("genesis 应签名");
        bytes[GENESIS_CURRENT_SIGNATURE_OFFSET..].copy_from_slice(signature.as_bytes());
        bytes
    }

    #[test]
    fn capsule_and_media_round_trip_preserve_fixed_bindings() {
        let user_id = UserId::new(uuid(0x11)).expect("账户应有效");
        let ark = AccountRootKey::from_bytes([0x21; 32]);
        let identity = RecoveryIdentity::generate(&mut TestRng(0x22)).expect("恢复身份应生成");
        let public_key = identity.public_key().expect("恢复公钥应派生");
        let capsule = seal_recovery_capsule(&mut TestRng(0x23), &ark, user_id, 1, 1, 1, public_key)
            .expect("capsule 应密封");
        let genesis = genesis(&ark, user_id, public_key, &capsule);
        let origin = [0x24; 32];
        let passphrase = "甲乙丙丁戊己庚辛壬癸子丑".as_bytes();
        let media = seal_recovery_media(
            &mut TestRng(0x25),
            &identity,
            user_id,
            1,
            &genesis,
            passphrase,
            &origin,
        )
        .expect("介质应密封");

        assert_eq!(capsule.as_bytes().len(), RECOVERY_CAPSULE_LENGTH);
        assert_eq!(media.as_bytes().len(), RECOVERY_MEDIA_LENGTH);
        let imported = open_recovery_media(&media, passphrase, &origin).expect("介质应打开");
        assert_eq!(imported.genesis.as_bytes(), &genesis);
        let opened = open_recovery_capsule(&imported.identity, user_id, 1, &capsule)
            .expect("capsule 应打开");
        assert_eq!(opened.user_id, user_id);
        assert_eq!(opened.key_epoch, 1);
        assert_eq!(opened.capsule_version, 1);
        assert_eq!(opened.ark.as_bytes(), ark.as_bytes());
    }

    #[test]
    fn old_media_opens_new_epoch_capsule_without_reexport() {
        let user_id = UserId::new(uuid(0x31)).expect("账户应有效");
        let epoch_one = AccountRootKey::from_bytes([0x32; 32]);
        let epoch_two = AccountRootKey::from_bytes([0x33; 32]);
        let identity = RecoveryIdentity::generate(&mut TestRng(0x34)).expect("恢复身份应生成");
        let public_key = identity.public_key().expect("恢复公钥应派生");
        let capsule_one =
            seal_recovery_capsule(&mut TestRng(0x35), &epoch_one, user_id, 1, 1, 1, public_key)
                .expect("初始 capsule 应密封");
        let genesis = genesis(&epoch_one, user_id, public_key, &capsule_one);
        let origin = [0x36; 32];
        let passphrase = b"recovery-passphrase-v1";
        let media = seal_recovery_media(
            &mut TestRng(0x37),
            &identity,
            user_id,
            1,
            &genesis,
            passphrase,
            &origin,
        )
        .expect("旧介质应密封");
        let capsule_two =
            seal_recovery_capsule(&mut TestRng(0x38), &epoch_two, user_id, 2, 1, 2, public_key)
                .expect("新 capsule 应密封");
        let imported = open_recovery_media(&media, passphrase, &origin).expect("旧介质应导入");
        let opened = open_recovery_capsule(&imported.identity, user_id, 1, &capsule_two)
            .expect("旧介质应打开新 capsule");
        assert_eq!(opened.key_epoch, 2);
        assert_eq!(opened.capsule_version, 2);
        assert_eq!(opened.ark.as_bytes(), epoch_two.as_bytes());
    }

    #[test]
    fn media_rejects_password_origin_tamper_and_invalid_genesis() {
        let user_id = UserId::new(uuid(0x41)).expect("账户应有效");
        let ark = AccountRootKey::from_bytes([0x42; 32]);
        let identity = RecoveryIdentity::generate(&mut TestRng(0x43)).expect("恢复身份应生成");
        let public_key = identity.public_key().expect("恢复公钥应派生");
        let capsule = seal_recovery_capsule(&mut TestRng(0x44), &ark, user_id, 1, 1, 1, public_key)
            .expect("capsule 应密封");
        let genesis = genesis(&ark, user_id, public_key, &capsule);
        let origin = [0x45; 32];
        let password = b"correct-password-v1";
        let media = seal_recovery_media(
            &mut TestRng(0x46),
            &identity,
            user_id,
            1,
            &genesis,
            password,
            &origin,
        )
        .expect("介质应密封");

        assert_eq!(
            open_recovery_media(&media, b"incorrect-password", &origin)
                .err()
                .expect("错误口令必须失败"),
            RecoveryCryptoError::MediaAuthenticationFailed
        );
        assert_eq!(
            open_recovery_media(&media, password, &[0x47; 32])
                .err()
                .expect("错误服务源必须失败"),
            RecoveryCryptoError::MediaOriginMismatch
        );
        let mut tampered = *media.as_bytes();
        tampered[MEDIA_CIPHERTEXT_OFFSET + 7] ^= 1;
        let tampered = RecoveryMedia::from_bytes(&tampered).expect("篡改不改变线结构");
        assert_eq!(
            open_recovery_media(&tampered, password, &origin)
                .err()
                .expect("篡改介质必须失败"),
            RecoveryCryptoError::MediaAuthenticationFailed
        );
        let mut invalid_genesis = genesis;
        invalid_genesis[28..32].copy_from_slice(&2_u32.to_be_bytes());
        assert_eq!(
            seal_recovery_media(
                &mut TestRng(0x48),
                &identity,
                user_id,
                1,
                &invalid_genesis,
                password,
                &origin,
            )
            .unwrap_err(),
            RecoveryCryptoError::InvalidGenesis
        );
    }

    #[test]
    fn wire_lengths_versions_and_passphrase_boundaries_are_strict() {
        assert!(matches!(
            RecoveryCapsule::from_bytes(&[0_u8; RECOVERY_CAPSULE_LENGTH - 1]),
            Err(RecoveryCryptoError::InvalidCapsuleLength { .. })
        ));
        assert!(matches!(
            RecoveryMedia::from_bytes(&[0_u8; RECOVERY_MEDIA_LENGTH - 1]),
            Err(RecoveryCryptoError::InvalidMediaLength { .. })
        ));
        assert_eq!(
            validate_passphrase("甲乙丙丁戊己庚辛壬癸子".as_bytes()),
            Err(RecoveryCryptoError::PassphraseTooShort)
        );
        assert_eq!(
            validate_passphrase("甲乙丙丁戊己庚辛壬癸子丑".as_bytes()),
            Ok(())
        );
        assert_eq!(validate_passphrase(&[b'a'; 128]), Ok(()));
        assert_eq!(
            validate_passphrase(&[b'a'; 129]),
            Err(RecoveryCryptoError::PassphraseTooLong)
        );
        assert_eq!(
            validate_passphrase(&[0xff; 12]),
            Err(RecoveryCryptoError::InvalidPassphraseUtf8)
        );
    }
}
