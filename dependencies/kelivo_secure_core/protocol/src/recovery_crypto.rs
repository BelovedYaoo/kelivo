//! 账户恢复 capsule 与独立口令恢复介质的唯一线格式；恢复介质当前为 v2。

use std::{fmt, str};

use argon2::{Algorithm, Argon2, Block, Params, Version};
use chacha20poly1305::{
    Tag, XChaCha20Poly1305, XNonce,
    aead::{AeadInOut, KeyInit},
};
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

use crate::{
    ARGON2_ITERATIONS, ARGON2_MEMORY_KIB, ARGON2_PARALLELISM,
    device_crypto::{
        AccountRootKey, AccountTrustBinding, AccountTrustPublicKey, AccountTrustSignature,
        DeviceId, DeviceKeyAgreementPublicKey, DeviceSigningPublicKey, HpkeRngAdapter, UserId,
        derive_account_trust_public_key, verify_account_trust_payload,
    },
    zeroizing_hkdf::expand_hkdf_sha256_single_block,
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
pub const RECOVERY_CAPSULE_SHA256_LENGTH: usize = 32;
const RECOVERY_CAPSULE_INFO_DOMAIN: &[u8] = b"kelivo.recovery-capsule.hpke-info.v1";

const RECOVERY_MEDIA_MAGIC: [u8; 8] = *b"KELVRM02";
pub const RECOVERY_MEDIA_VERSION: u16 = 2;
pub const RECOVERY_MEDIA_SUITE_ID: u16 = 1;
pub const RECOVERY_MEDIA_KDF_PROFILE_ID: u16 = 1;
const RECOVERY_MEDIA_FLAGS: u16 = 0;
pub const RECOVERY_MEDIA_HEADER_LENGTH: usize = 96;
pub const RECOVERY_MEDIA_PLAINTEXT_LENGTH: usize = 564;
pub const RECOVERY_MEDIA_SALT_LENGTH: usize = 16;
pub const RECOVERY_MEDIA_NONCE_LENGTH: usize = 24;
pub const RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH: usize = 32;
pub const RECOVERY_GENESIS_LENGTH: usize = 476;
pub const RECOVERY_MEDIA_TAG_LENGTH: usize = 16;
pub const RECOVERY_MEDIA_LENGTH: usize = 676;
pub const RECOVERY_HISTORY_MAX_BYTES: usize = 16 * 1024 * 1024;
pub const RECOVERY_PASSPHRASE_MIN_SCALARS: usize = 12;
pub const RECOVERY_PASSPHRASE_MAX_UTF8_LENGTH: usize = 128;
const RECOVERY_MEDIA_WRAP_KEY_INFO: &[u8] = b"kelivo.recovery-media.wrap-key.v2";
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

const GENESIS_PAYLOAD_LENGTH: usize = 348;
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
    CapsuleBindingMismatch,
    InitialCapsuleMismatch,
    InitialCapsuleArkMismatch,
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
    GenesisTrustRootMismatch,
    GenesisCapsuleDigestMismatch,
    GenesisSignatureInvalid,
    InvalidMembershipHistory,
    MembershipHistoryAnchorMismatch,
    MembershipHistoryTransitionInvalid,
    MembershipHistorySignatureInvalid,
    MembershipHistoryHeadMismatch,
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
            Self::CapsuleBindingMismatch => formatter.write_str("恢复 capsule 历史头绑定不匹配"),
            Self::InitialCapsuleMismatch => formatter.write_str("恢复初始 capsule 绑定不匹配"),
            Self::InitialCapsuleArkMismatch => {
                formatter.write_str("恢复初始 capsule 与本地账户根密钥不匹配")
            }
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
            Self::GenesisTrustRootMismatch => {
                formatter.write_str("恢复介质 genesis 与本地账户信任根不匹配")
            }
            Self::GenesisCapsuleDigestMismatch => {
                formatter.write_str("恢复介质 genesis 与初始 capsule 摘要不匹配")
            }
            Self::GenesisSignatureInvalid => formatter.write_str("恢复介质 genesis 签名无效"),
            Self::InvalidMembershipHistory => formatter.write_str("恢复成员历史线格式无效"),
            Self::MembershipHistoryAnchorMismatch => {
                formatter.write_str("恢复成员历史与介质 genesis 锚不匹配")
            }
            Self::MembershipHistoryTransitionInvalid => {
                formatter.write_str("恢复成员历史状态转换无效")
            }
            Self::MembershipHistorySignatureInvalid => formatter.write_str("恢复成员历史签名无效"),
            Self::MembershipHistoryHeadMismatch => {
                formatter.write_str("恢复成员历史链头与当前 capsule 不匹配")
            }
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

    pub(crate) fn hpke_private_key(
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

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct RecoveryCapsuleExpectation {
    user_id: UserId,
    key_epoch: u32,
    recovery_public_key_version: u32,
    capsule_version: u32,
    capsule_sha256: [u8; RECOVERY_CAPSULE_SHA256_LENGTH],
}

impl RecoveryCapsuleExpectation {
    pub(crate) fn new(
        user_id: UserId,
        key_epoch: u32,
        recovery_public_key_version: u32,
        capsule_version: u32,
        capsule_sha256: [u8; RECOVERY_CAPSULE_SHA256_LENGTH],
    ) -> Result<Self, RecoveryCryptoError> {
        require_positive(key_epoch)?;
        require_positive(recovery_public_key_version)?;
        require_positive(capsule_version)?;
        Ok(Self {
            user_id,
            key_epoch,
            recovery_public_key_version,
            capsule_version,
            capsule_sha256,
        })
    }
}

#[derive(Clone, Copy)]
pub struct RecoveryMediaExportAuthority<'a> {
    local_epoch_one_ark: &'a AccountRootKey,
    initial_capsule: &'a RecoveryCapsule,
    genesis: &'a [u8],
}

impl<'a> RecoveryMediaExportAuthority<'a> {
    pub const fn new(
        local_epoch_one_ark: &'a AccountRootKey,
        initial_capsule: &'a RecoveryCapsule,
        genesis: &'a [u8],
    ) -> Self {
        Self {
            local_epoch_one_ark,
            initial_capsule,
            genesis,
        }
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

pub struct OpenedRecoveryKeyring {
    pub current: OpenedRecoveryCapsule,
    pub source: Option<OpenedRecoveryCapsule>,
    pub history_head: VerifiedRecoveryHistoryHead,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct RecoveryHistoryMember {
    pub device_id: DeviceId,
    pub key_version: u32,
    pub auth_generation: u32,
    pub signing_public_key: DeviceSigningPublicKey,
    pub key_agreement_public_key: DeviceKeyAgreementPublicKey,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct VerifiedRecoveryHistoryHead {
    pub user_id: UserId,
    pub security_generation: u32,
    pub key_epoch: u32,
    pub digest: [u8; 32],
    pub current_trust_public_key: AccountTrustPublicKey,
    pub recovery_public_key_version: u32,
    pub recovery_public_key: RecoveryPublicKey,
    pub recovery_capsule_version: u32,
    pub recovery_capsule_digest: [u8; RECOVERY_CAPSULE_SHA256_LENGTH],
    pub operation_kind: u32,
    pub operation_id: [u8; 16],
    pub issuer_device_id: DeviceId,
    pub subject_device_id: DeviceId,
    pub members: Vec<RecoveryHistoryMember>,
    pub operation_ids: Vec<[u8; 16]>,
    pub manifest: Vec<u8>,
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
    let mut rng =
        HpkeRngAdapter::from_rng(rng).map_err(|_| RecoveryCryptoError::RandomnessUnavailable)?;
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

fn open_recovery_capsule(
    identity: &RecoveryIdentity,
    expectation: RecoveryCapsuleExpectation,
    capsule: &RecoveryCapsule,
) -> Result<OpenedRecoveryCapsule, RecoveryCryptoError> {
    let user_id = capsule.user_id()?;
    let recovery_public_key = capsule.recovery_public_key()?;
    let capsule_sha256 = Sha256::digest(capsule.as_bytes());
    if user_id != expectation.user_id
        || capsule.key_epoch() != expectation.key_epoch
        || capsule.recovery_public_key_version() != expectation.recovery_public_key_version
        || capsule.capsule_version() != expectation.capsule_version
        || !same_bytes(&capsule_sha256, &expectation.capsule_sha256)
    {
        return Err(RecoveryCryptoError::CapsuleBindingMismatch);
    }
    if recovery_public_key != identity.public_key()? {
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

pub fn verify_recovery_history_and_open_capsules(
    identity: &RecoveryIdentity,
    user_id: UserId,
    recovery_public_key_version: u32,
    genesis: &RecoveryGenesisCapability,
    membership_history: &[u8],
    source_capsule: Option<&RecoveryCapsule>,
    current_capsule: &RecoveryCapsule,
) -> Result<OpenedRecoveryKeyring, RecoveryCryptoError> {
    let expectations = crate::recovery_history::verify_history_head(
        identity.public_key()?,
        user_id,
        recovery_public_key_version,
        genesis,
        membership_history,
        source_capsule,
        current_capsule,
    )?;
    let current = open_recovery_capsule(identity, expectations.current, current_capsule)?;
    let source = match (expectations.source, source_capsule) {
        (Some(expectation), Some(capsule)) => {
            Some(open_recovery_capsule(identity, expectation, capsule)?)
        }
        (None, None) => None,
        _ => return Err(RecoveryCryptoError::MembershipHistoryHeadMismatch),
    };
    Ok(OpenedRecoveryKeyring {
        current,
        source,
        history_head: expectations.history_head,
    })
}

#[cfg(test)]
fn verify_recovery_history_and_open_current_capsule(
    identity: &RecoveryIdentity,
    user_id: UserId,
    recovery_public_key_version: u32,
    genesis: &RecoveryGenesisCapability,
    membership_history: &[u8],
    current_capsule: &RecoveryCapsule,
) -> Result<OpenedRecoveryCapsule, RecoveryCryptoError> {
    verify_recovery_history_and_open_capsules(
        identity,
        user_id,
        recovery_public_key_version,
        genesis,
        membership_history,
        None,
        current_capsule,
    )
    .map(|opened| opened.current)
}

pub fn seal_recovery_media<R>(
    rng: &mut R,
    identity: &RecoveryIdentity,
    user_id: UserId,
    recovery_public_key_version: u32,
    authority: RecoveryMediaExportAuthority<'_>,
    passphrase: &[u8],
    service_origin_sha256: &[u8; RECOVERY_SERVICE_ORIGIN_DIGEST_LENGTH],
) -> Result<RecoveryMedia, RecoveryCryptoError>
where
    R: CryptoRng + RngCore,
{
    require_positive(recovery_public_key_version)?;
    validate_passphrase(passphrase)?;
    let recovery_public_key = identity.public_key()?;
    let initial_capsule = authority.initial_capsule;
    let genesis = authority.genesis;
    if initial_capsule.user_id()? != user_id
        || initial_capsule.key_epoch() != 1
        || initial_capsule.recovery_public_key_version() != recovery_public_key_version
        || initial_capsule.capsule_version() != 1
        || initial_capsule.recovery_public_key()? != recovery_public_key
    {
        return Err(RecoveryCryptoError::InitialCapsuleMismatch);
    }
    let initial_capsule_sha256: [u8; RECOVERY_CAPSULE_SHA256_LENGTH] =
        Sha256::digest(initial_capsule.as_bytes()).into();
    let opened_initial_capsule = open_recovery_capsule(
        identity,
        RecoveryCapsuleExpectation::new(
            user_id,
            1,
            recovery_public_key_version,
            1,
            initial_capsule_sha256,
        )?,
        initial_capsule,
    )?;
    if !same_bytes(
        opened_initial_capsule.ark.as_bytes(),
        authority.local_epoch_one_ark.as_bytes(),
    ) {
        return Err(RecoveryCryptoError::InitialCapsuleArkMismatch);
    }
    let trust_public_key = derive_account_trust_public_key(
        authority.local_epoch_one_ark,
        AccountTrustBinding {
            user_id,
            key_epoch: 1,
        },
    )
    .map_err(|_| RecoveryCryptoError::GenesisTrustRootMismatch)?;
    let capability = validate_genesis(
        genesis,
        user_id,
        recovery_public_key_version,
        recovery_public_key,
    )?;
    if !same_bytes(&genesis[68..100], trust_public_key.as_bytes()) {
        return Err(RecoveryCryptoError::GenesisTrustRootMismatch);
    }
    if !same_bytes(&genesis[140..172], &initial_capsule_sha256) {
        return Err(RecoveryCryptoError::GenesisCapsuleDigestMismatch);
    }

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
    let block_count = params.block_count();
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut memory = Zeroizing::new(Vec::<Block>::new());
    memory
        .try_reserve_exact(block_count)
        .map_err(|_| RecoveryCryptoError::MediaKdfFailed)?;
    memory.resize(block_count, Block::default());
    let mut intermediate = Zeroizing::new([0_u8; RECOVERY_MEDIA_KEY_LENGTH]);
    argon2
        .hash_password_into_with_memory(
            passphrase,
            salt,
            intermediate.as_mut_slice(),
            memory.as_mut_slice(),
        )
        .map_err(|_| RecoveryCryptoError::MediaKdfFailed)?;

    let mut key = Zeroizing::new([0_u8; RECOVERY_MEDIA_KEY_LENGTH]);
    expand_hkdf_sha256_single_block(
        None,
        intermediate.as_slice(),
        RECOVERY_MEDIA_WRAP_KEY_INFO,
        &mut key,
    )
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
        || read_u32(genesis, 8) != 2
        || genesis[12..28] != *expected_user_id.as_bytes()
        || read_u32(genesis, 28) != 1
        || read_u32(genesis, 32) != 1
        || genesis[36..68].iter().any(|byte| *byte != 0)
        || read_u32(genesis, 100) != expected_recovery_public_key_version
        || genesis[104..136] != *expected_recovery_public_key.as_bytes()
        || read_u32(genesis, 136) != 1
        || read_u32(genesis, 172) != 1
        || genesis[224..256].iter().any(|byte| *byte != 0)
        || read_u32(genesis, 256) != 1
        || genesis[192..208] != genesis[208..224]
        || genesis[208..224] != genesis[260..276]
        || read_u32(genesis, 276) == 0
        || read_u32(genesis, 276) > 0x7fff_ffff
        || read_u32(genesis, 280) != 0
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
    DeviceSigningPublicKey::from_bytes(copy_array(&genesis[284..316]))
        .map_err(|_| RecoveryCryptoError::InvalidGenesis)?;
    let member_key_agreement =
        DeviceKeyAgreementPublicKey::from_bytes(copy_array(&genesis[316..348]))
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

#[cfg(test)]
mod tests {
    use std::num::NonZeroU32;

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

    struct FailingRng;

    impl RngCore for FailingRng {
        fn next_u32(&mut self) -> u32 {
            panic!("失败随机源不得回退到不可失败接口")
        }

        fn next_u64(&mut self) -> u64 {
            panic!("失败随机源不得回退到不可失败接口")
        }

        fn fill_bytes(&mut self, _destination: &mut [u8]) {
            panic!("失败随机源不得回退到不可失败接口")
        }

        fn try_fill_bytes(&mut self, _destination: &mut [u8]) -> Result<(), rand::Error> {
            let code = NonZeroU32::new(rand::Error::CUSTOM_START).expect("随机错误码必须有效");
            Err(rand::Error::from(code))
        }
    }

    impl CryptoRng for FailingRng {}

    #[test]
    fn recovery_media_kdf_v2_vector_remains_stable() {
        let key = derive_media_key(
            b"recovery-passphrase-v1",
            &[0x5a; RECOVERY_MEDIA_SALT_LENGTH],
        )
        .expect("恢复介质 KDF 固定向量应派生");
        assert_eq!(
            key.as_slice(),
            &[
                0x4e, 0xa8, 0xaa, 0x5c, 0xe4, 0xf7, 0xb5, 0x61, 0x26, 0xe1, 0x69, 0x51, 0x15, 0xaa,
                0x16, 0xa1, 0xcd, 0xa3, 0xa5, 0xbb, 0xe7, 0x49, 0x87, 0x15, 0x9f, 0xdb, 0xe1, 0xd7,
                0xc1, 0xe6, 0x95, 0x54,
            ]
        );
    }

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
        bytes[8..12].copy_from_slice(&2_u32.to_be_bytes());
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
        bytes[256..260].copy_from_slice(&1_u32.to_be_bytes());
        bytes[260..276].copy_from_slice(&device_id);
        bytes[276..280].copy_from_slice(&1_u32.to_be_bytes());
        bytes[284..316].copy_from_slice(member_public.signing.as_bytes());
        bytes[316..348].copy_from_slice(member_public.key_agreement.as_bytes());
        let signature = sign_account_trust_payload(ark, binding, &bytes[..GENESIS_PAYLOAD_LENGTH])
            .expect("genesis 应签名");
        bytes[GENESIS_CURRENT_SIGNATURE_OFFSET..].copy_from_slice(signature.as_bytes());
        bytes
    }

    fn expectation(capsule: &RecoveryCapsule) -> RecoveryCapsuleExpectation {
        RecoveryCapsuleExpectation::new(
            capsule.user_id().expect("capsule 账户应有效"),
            capsule.key_epoch(),
            capsule.recovery_public_key_version(),
            capsule.capsule_version(),
            Sha256::digest(capsule.as_bytes()).into(),
        )
        .expect("capsule 历史头绑定应有效")
    }

    struct RecoveryHistoryFixture {
        user_id: UserId,
        epoch_one: AccountRootKey,
        epoch_two: AccountRootKey,
        epoch_three: AccountRootKey,
        identity: RecoveryIdentity,
        capsule_one: RecoveryCapsule,
        capsule_two: RecoveryCapsule,
        capsule_three: RecoveryCapsule,
        genesis: [u8; RECOVERY_GENESIS_LENGTH],
        genesis_capability: RecoveryGenesisCapability,
        add_device: Vec<u8>,
        revoke_rotate: Vec<u8>,
        recover_resume: Vec<u8>,
        recover_replace: Vec<u8>,
    }

    impl RecoveryHistoryFixture {
        fn new() -> Self {
            let user_id = UserId::new(uuid(0x81)).expect("账户应有效");
            let epoch_one = AccountRootKey::from_bytes([0x82; 32]);
            let epoch_two = AccountRootKey::from_bytes([0x83; 32]);
            let identity = RecoveryIdentity::generate(&mut TestRng(0x84)).expect("恢复身份应生成");
            let public_key = identity.public_key().expect("恢复公钥应派生");
            let capsule_one =
                seal_recovery_capsule(&mut TestRng(0x85), &epoch_one, user_id, 1, 1, 1, public_key)
                    .expect("初始 capsule 应密封");
            let genesis = genesis(&epoch_one, user_id, public_key, &capsule_one);
            let genesis_capability =
                validate_genesis(&genesis, user_id, 1, public_key).expect("genesis 应验证");
            let add_device = build_add_device_manifest(&genesis, &epoch_one, user_id);
            let capsule_two =
                seal_recovery_capsule(&mut TestRng(0x86), &epoch_two, user_id, 2, 1, 2, public_key)
                    .expect("轮换 capsule 应密封");
            let revoke_rotate = build_revoke_rotate_manifest(
                &add_device,
                &epoch_one,
                &epoch_two,
                user_id,
                &capsule_two,
            );
            let recover_resume =
                build_recover_resume_manifest(&revoke_rotate, &epoch_two, user_id, 0x73, 0x74);
            let epoch_three = AccountRootKey::from_bytes([0x87; 32]);
            let capsule_three = seal_recovery_capsule(
                &mut TestRng(0x88),
                &epoch_three,
                user_id,
                3,
                1,
                3,
                public_key,
            )
            .expect("恢复替换 capsule 应密封");
            let recover_replace = build_recover_replace_manifest(
                &recover_resume,
                &epoch_two,
                &epoch_three,
                user_id,
                &capsule_three,
                None,
            );
            Self {
                user_id,
                epoch_one,
                epoch_two,
                epoch_three,
                identity,
                capsule_one,
                capsule_two,
                capsule_three,
                genesis,
                genesis_capability,
                add_device,
                revoke_rotate,
                recover_resume,
                recover_replace,
            }
        }

        fn history(&self, successors: &[&[u8]]) -> Vec<u8> {
            let mut history = Vec::from(self.genesis);
            for successor in successors {
                history.extend_from_slice(successor);
            }
            history
        }
    }

    fn build_add_device_manifest(
        previous: &[u8; RECOVERY_GENESIS_LENGTH],
        ark: &AccountRootKey,
        user_id: UserId,
    ) -> Vec<u8> {
        const HEADER_LENGTH: usize = 260;
        const MEMBER_LENGTH: usize = 88;
        const SIGNATURE_SECTION_LENGTH: usize = 128;
        let payload_length = HEADER_LENGTH + 2 * MEMBER_LENGTH;
        let mut manifest = vec![0_u8; payload_length + SIGNATURE_SECTION_LENGTH];
        manifest[..HEADER_LENGTH].copy_from_slice(&previous[..HEADER_LENGTH]);
        manifest[28..32].copy_from_slice(&2_u32.to_be_bytes());
        manifest[36..68].copy_from_slice(&Sha256::digest(previous));
        manifest[172..176].copy_from_slice(&2_u32.to_be_bytes());
        manifest[176..192].copy_from_slice(&uuid(0x61));
        manifest[192..208].copy_from_slice(&previous[260..276]);
        let subject_id = uuid(0x63);
        manifest[208..224].copy_from_slice(&subject_id);
        manifest[224..256].fill(0);
        manifest[256..260].copy_from_slice(&2_u32.to_be_bytes());
        manifest[260..348].copy_from_slice(&previous[260..348]);

        let subject = DeviceIdentity::generate(&mut TestRng(0x64)).expect("新增设备身份应生成");
        let subject_public = subject.public_keys();
        manifest[348..364].copy_from_slice(&subject_id);
        manifest[364..368].copy_from_slice(&1_u32.to_be_bytes());
        manifest[368..372].copy_from_slice(&1_u32.to_be_bytes());
        manifest[372..404].copy_from_slice(subject_public.signing.as_bytes());
        manifest[404..436].copy_from_slice(subject_public.key_agreement.as_bytes());
        sign_history_manifest(&mut manifest, user_id, None, (ark, 1));
        manifest
    }

    fn build_revoke_rotate_manifest(
        previous: &[u8],
        previous_ark: &AccountRootKey,
        current_ark: &AccountRootKey,
        user_id: UserId,
        capsule: &RecoveryCapsule,
    ) -> Vec<u8> {
        const HEADER_LENGTH: usize = 260;
        const MEMBER_LENGTH: usize = 88;
        const SIGNATURE_SECTION_LENGTH: usize = 128;
        let payload_length = HEADER_LENGTH + MEMBER_LENGTH;
        let mut manifest = vec![0_u8; payload_length + SIGNATURE_SECTION_LENGTH];
        manifest[..HEADER_LENGTH].copy_from_slice(&previous[..HEADER_LENGTH]);
        manifest[28..32].copy_from_slice(&3_u32.to_be_bytes());
        manifest[32..36].copy_from_slice(&2_u32.to_be_bytes());
        manifest[36..68].copy_from_slice(&Sha256::digest(previous));
        let trust_public = derive_account_trust_public_key(
            current_ark,
            AccountTrustBinding {
                user_id,
                key_epoch: 2,
            },
        )
        .expect("轮换信任公钥应派生");
        manifest[68..100].copy_from_slice(trust_public.as_bytes());
        manifest[136..140].copy_from_slice(&2_u32.to_be_bytes());
        manifest[140..172].copy_from_slice(&Sha256::digest(capsule.as_bytes()));
        manifest[172..176].copy_from_slice(&3_u32.to_be_bytes());
        manifest[176..192].copy_from_slice(&uuid(0x65));
        manifest[192..208].copy_from_slice(&previous[260..276]);
        manifest[208..224].copy_from_slice(&previous[348..364]);
        manifest[224..256].fill(0);
        manifest[256..260].copy_from_slice(&1_u32.to_be_bytes());
        manifest[260..348].copy_from_slice(&previous[260..348]);
        sign_history_manifest(
            &mut manifest,
            user_id,
            Some((previous_ark, 1)),
            (current_ark, 2),
        );
        manifest
    }

    fn build_recover_resume_manifest(
        previous: &[u8],
        ark: &AccountRootKey,
        user_id: UserId,
        subject_id_seed: u8,
        subject_key_seed: u8,
    ) -> Vec<u8> {
        const HEADER_LENGTH: usize = 260;
        const MEMBER_LENGTH: usize = 88;
        const SIGNATURE_SECTION_LENGTH: usize = 128;
        let previous_member_count = u32::from_be_bytes(copy_array(&previous[256..260])) as usize;
        let previous_payload_length = previous.len() - SIGNATURE_SECTION_LENGTH;
        let payload_length = HEADER_LENGTH + (previous_member_count + 1) * MEMBER_LENGTH;
        let mut manifest = vec![0_u8; payload_length + SIGNATURE_SECTION_LENGTH];
        manifest[..HEADER_LENGTH].copy_from_slice(&previous[..HEADER_LENGTH]);
        let next_generation = u32::from_be_bytes(copy_array(&previous[28..32])) + 1;
        let key_epoch = u32::from_be_bytes(copy_array(&previous[32..36]));
        manifest[28..32].copy_from_slice(&next_generation.to_be_bytes());
        manifest[36..68].copy_from_slice(&Sha256::digest(previous));
        manifest[172..176].copy_from_slice(&4_u32.to_be_bytes());
        manifest[176..192].copy_from_slice(&uuid(subject_id_seed.wrapping_add(1)));
        let subject_id = uuid(subject_id_seed);
        manifest[192..208].copy_from_slice(&subject_id);
        manifest[208..224].copy_from_slice(&subject_id);
        manifest[224..256].fill(0);
        manifest[256..260].copy_from_slice(&((previous_member_count + 1) as u32).to_be_bytes());
        manifest[HEADER_LENGTH..previous_payload_length]
            .copy_from_slice(&previous[HEADER_LENGTH..previous_payload_length]);

        let subject =
            DeviceIdentity::generate(&mut TestRng(subject_key_seed)).expect("恢复设备身份应生成");
        let subject_public = subject.public_keys();
        let subject_offset = previous_payload_length;
        manifest[subject_offset..subject_offset + 16].copy_from_slice(&subject_id);
        manifest[subject_offset + 16..subject_offset + 20].copy_from_slice(&1_u32.to_be_bytes());
        manifest[subject_offset + 20..subject_offset + 24].copy_from_slice(&1_u32.to_be_bytes());
        manifest[subject_offset + 24..subject_offset + 56]
            .copy_from_slice(subject_public.signing.as_bytes());
        manifest[subject_offset + 56..subject_offset + MEMBER_LENGTH]
            .copy_from_slice(subject_public.key_agreement.as_bytes());
        sign_history_manifest(&mut manifest, user_id, None, (ark, key_epoch));
        manifest
    }

    fn build_recover_replace_manifest(
        previous: &[u8],
        previous_ark: &AccountRootKey,
        current_ark: &AccountRootKey,
        user_id: UserId,
        capsule: &RecoveryCapsule,
        direct_subject: Option<(u8, u8)>,
    ) -> Vec<u8> {
        const HEADER_LENGTH: usize = 260;
        const MEMBER_LENGTH: usize = 88;
        const SIGNATURE_SECTION_LENGTH: usize = 128;
        let payload_length = HEADER_LENGTH + MEMBER_LENGTH;
        let mut manifest = vec![0_u8; payload_length + SIGNATURE_SECTION_LENGTH];
        manifest[..HEADER_LENGTH].copy_from_slice(&previous[..HEADER_LENGTH]);
        let next_generation = u32::from_be_bytes(copy_array(&previous[28..32])) + 1;
        let previous_epoch = u32::from_be_bytes(copy_array(&previous[32..36]));
        let current_epoch = previous_epoch + 1;
        let previous_capsule_version = u32::from_be_bytes(copy_array(&previous[136..140]));
        manifest[28..32].copy_from_slice(&next_generation.to_be_bytes());
        manifest[32..36].copy_from_slice(&current_epoch.to_be_bytes());
        manifest[36..68].copy_from_slice(&Sha256::digest(previous));
        let trust_public = derive_account_trust_public_key(
            current_ark,
            AccountTrustBinding {
                user_id,
                key_epoch: current_epoch,
            },
        )
        .expect("恢复替换信任公钥应派生");
        manifest[68..100].copy_from_slice(trust_public.as_bytes());
        manifest[136..140].copy_from_slice(&(previous_capsule_version + 1).to_be_bytes());
        manifest[140..172].copy_from_slice(&Sha256::digest(capsule.as_bytes()));
        manifest[172..176].copy_from_slice(&5_u32.to_be_bytes());
        manifest[176..192].copy_from_slice(&uuid(0x76));
        manifest[224..256].fill(0);
        manifest[256..260].copy_from_slice(&1_u32.to_be_bytes());

        let member = match direct_subject {
            Some((subject_id_seed, subject_key_seed)) => {
                let subject_id = uuid(subject_id_seed);
                let subject = DeviceIdentity::generate(&mut TestRng(subject_key_seed))
                    .expect("直接恢复替换身份应生成");
                let public = subject.public_keys();
                let mut member = [0_u8; MEMBER_LENGTH];
                member[..16].copy_from_slice(&subject_id);
                member[16..20].copy_from_slice(&1_u32.to_be_bytes());
                member[20..24].copy_from_slice(&1_u32.to_be_bytes());
                member[24..56].copy_from_slice(public.signing.as_bytes());
                member[56..].copy_from_slice(public.key_agreement.as_bytes());
                member
            }
            None => {
                let previous_payload_length = previous.len() - SIGNATURE_SECTION_LENGTH;
                copy_array(
                    &previous[previous_payload_length - MEMBER_LENGTH..previous_payload_length],
                )
            }
        };
        manifest[192..208].copy_from_slice(&member[..16]);
        manifest[208..224].copy_from_slice(&member[..16]);
        manifest[HEADER_LENGTH..payload_length].copy_from_slice(&member);
        sign_history_manifest(
            &mut manifest,
            user_id,
            Some((previous_ark, previous_epoch)),
            (current_ark, current_epoch),
        );
        manifest
    }

    fn sign_history_manifest(
        manifest: &mut [u8],
        user_id: UserId,
        transition: Option<(&AccountRootKey, u32)>,
        current: (&AccountRootKey, u32),
    ) {
        let payload_length = manifest.len() - 128;
        manifest[payload_length..].fill(0);
        if let Some((ark, key_epoch)) = transition {
            let signature = sign_account_trust_payload(
                ark,
                AccountTrustBinding { user_id, key_epoch },
                &manifest[..payload_length],
            )
            .expect("历史过渡签名应生成");
            manifest[payload_length..payload_length + 64].copy_from_slice(signature.as_bytes());
        }
        let signature = sign_account_trust_payload(
            current.0,
            AccountTrustBinding {
                user_id,
                key_epoch: current.1,
            },
            &manifest[..payload_length],
        )
        .expect("历史当前签名应生成");
        manifest[payload_length + 64..].copy_from_slice(signature.as_bytes());
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
            RecoveryMediaExportAuthority::new(&ark, &capsule, &genesis),
            passphrase,
            &origin,
        )
        .expect("介质应密封");

        assert_eq!(capsule.as_bytes().len(), RECOVERY_CAPSULE_LENGTH);
        assert_eq!(media.as_bytes().len(), RECOVERY_MEDIA_LENGTH);
        let imported = open_recovery_media(&media, passphrase, &origin).expect("介质应打开");
        assert_eq!(imported.genesis.as_bytes(), &genesis);
        let opened = open_recovery_capsule(&imported.identity, expectation(&capsule), &capsule)
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
            RecoveryMediaExportAuthority::new(&epoch_one, &capsule_one, &genesis),
            passphrase,
            &origin,
        )
        .expect("旧介质应密封");
        let capsule_two =
            seal_recovery_capsule(&mut TestRng(0x38), &epoch_two, user_id, 2, 1, 2, public_key)
                .expect("新 capsule 应密封");
        let imported = open_recovery_media(&media, passphrase, &origin).expect("旧介质应导入");
        let opened =
            open_recovery_capsule(&imported.identity, expectation(&capsule_two), &capsule_two)
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
            RecoveryMediaExportAuthority::new(&ark, &capsule, &genesis),
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
                RecoveryMediaExportAuthority::new(&ark, &capsule, &invalid_genesis),
                password,
                &origin,
            )
            .unwrap_err(),
            RecoveryCryptoError::InvalidGenesis
        );
    }

    #[test]
    fn media_rejects_self_signed_genesis_without_local_ark_authority() {
        let user_id = UserId::new(uuid(0x51)).expect("账户应有效");
        let local_ark = AccountRootKey::from_bytes([0x52; 32]);
        let attacker_ark = AccountRootKey::from_bytes([0x53; 32]);
        let identity = RecoveryIdentity::generate(&mut TestRng(0x54)).expect("恢复身份应生成");
        let public_key = identity.public_key().expect("恢复公钥应派生");
        let attacker_capsule = seal_recovery_capsule(
            &mut TestRng(0x55),
            &attacker_ark,
            user_id,
            1,
            1,
            1,
            public_key,
        )
        .expect("攻击者 capsule 应能独立构造");
        let attacker_genesis = genesis(&attacker_ark, user_id, public_key, &attacker_capsule);

        assert_ne!(local_ark.as_bytes(), attacker_ark.as_bytes());
        assert_eq!(
            seal_recovery_media(
                &mut TestRng(0x56),
                &identity,
                user_id,
                1,
                RecoveryMediaExportAuthority::new(
                    &local_ark,
                    &attacker_capsule,
                    &attacker_genesis,
                ),
                b"recovery-passphrase-v1",
                &[0x57; 32],
            )
            .unwrap_err(),
            RecoveryCryptoError::InitialCapsuleArkMismatch
        );
    }

    #[test]
    fn media_rejects_genesis_bound_to_a_different_initial_capsule() {
        let user_id = UserId::new(uuid(0x61)).expect("账户应有效");
        let ark = AccountRootKey::from_bytes([0x62; 32]);
        let identity = RecoveryIdentity::generate(&mut TestRng(0x63)).expect("恢复身份应生成");
        let public_key = identity.public_key().expect("恢复公钥应派生");
        let expected_capsule =
            seal_recovery_capsule(&mut TestRng(0x64), &ark, user_id, 1, 1, 1, public_key)
                .expect("初始 capsule 应密封");
        let other_capsule =
            seal_recovery_capsule(&mut TestRng(0x65), &ark, user_id, 1, 1, 1, public_key)
                .expect("另一个 capsule 应密封");
        let mismatched_genesis = genesis(&ark, user_id, public_key, &other_capsule);

        assert_ne!(expected_capsule.as_bytes(), other_capsule.as_bytes());
        assert_eq!(
            seal_recovery_media(
                &mut TestRng(0x66),
                &identity,
                user_id,
                1,
                RecoveryMediaExportAuthority::new(&ark, &expected_capsule, &mismatched_genesis,),
                b"recovery-passphrase-v1",
                &[0x67; 32],
            )
            .unwrap_err(),
            RecoveryCryptoError::GenesisCapsuleDigestMismatch
        );
    }

    #[test]
    fn capsule_open_rejects_untrusted_history_head_binding() {
        let user_id = UserId::new(uuid(0x68)).expect("账户应有效");
        let ark = AccountRootKey::from_bytes([0x69; 32]);
        let identity = RecoveryIdentity::generate(&mut TestRng(0x6a)).expect("恢复身份应生成");
        let public_key = identity.public_key().expect("恢复公钥应派生");
        let capsule = seal_recovery_capsule(&mut TestRng(0x6b), &ark, user_id, 2, 1, 3, public_key)
            .expect("capsule 应密封");
        let wrong_expectation = RecoveryCapsuleExpectation::new(
            user_id,
            2,
            1,
            3,
            [0x6c; RECOVERY_CAPSULE_SHA256_LENGTH],
        )
        .expect("历史头绑定应有效");

        assert_eq!(
            open_recovery_capsule(&identity, wrong_expectation, &capsule)
                .err()
                .expect("未获历史头授权的 capsule 必须失败"),
            RecoveryCryptoError::CapsuleBindingMismatch
        );
    }

    #[test]
    fn capsule_seal_preserves_fallible_rng_errors() {
        let user_id = UserId::new(uuid(0x71)).expect("账户应有效");
        let ark = AccountRootKey::from_bytes([0x72; 32]);
        let identity = RecoveryIdentity::generate(&mut TestRng(0x73)).expect("恢复身份应生成");
        let public_key = identity.public_key().expect("恢复公钥应派生");

        assert_eq!(
            seal_recovery_capsule(&mut FailingRng, &ark, user_id, 1, 1, 1, public_key).unwrap_err(),
            RecoveryCryptoError::RandomnessUnavailable
        );
    }

    #[test]
    fn recovery_history_opens_genesis_and_rotated_heads() {
        let fixture = RecoveryHistoryFixture::new();
        let genesis_history = fixture.history(&[]);
        let opened_genesis = verify_recovery_history_and_open_current_capsule(
            &fixture.identity,
            fixture.user_id,
            1,
            &fixture.genesis_capability,
            &genesis_history,
            &fixture.capsule_one,
        )
        .expect("genesis 链头应打开初始 capsule");
        assert_eq!(opened_genesis.key_epoch, 1);
        assert_eq!(opened_genesis.ark.as_bytes(), fixture.epoch_one.as_bytes());

        let rotated_history = fixture.history(&[
            fixture.add_device.as_slice(),
            fixture.revoke_rotate.as_slice(),
        ]);
        let opened_rotated = verify_recovery_history_and_open_capsules(
            &fixture.identity,
            fixture.user_id,
            1,
            &fixture.genesis_capability,
            &rotated_history,
            Some(&fixture.capsule_one),
            &fixture.capsule_two,
        )
        .expect("完整 add/revokeRotate 历史应打开当前 capsule");
        assert_eq!(opened_rotated.current.key_epoch, 2);
        assert_eq!(opened_rotated.current.capsule_version, 2);
        assert_eq!(opened_rotated.current.ark.as_bytes(), &[0x83; 32]);
        assert_eq!(
            opened_rotated
                .source
                .expect("轮换历史必须同时打开直接前驱 ARK")
                .ark
                .as_bytes(),
            fixture.epoch_one.as_bytes()
        );
    }

    #[test]
    fn recovery_history_opens_exact_adjacent_keyring() {
        let fixture = RecoveryHistoryFixture::new();
        let genesis_history = fixture.history(&[]);
        assert_eq!(
            verify_recovery_history_and_open_capsules(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &genesis_history,
                Some(&fixture.capsule_one),
                &fixture.capsule_one,
            )
            .err()
            .expect("epoch 一不得接受多余源 capsule"),
            RecoveryCryptoError::MembershipHistoryHeadMismatch
        );
        let rotated_history = fixture.history(&[
            fixture.add_device.as_slice(),
            fixture.revoke_rotate.as_slice(),
            fixture.recover_resume.as_slice(),
        ]);
        let opened = verify_recovery_history_and_open_capsules(
            &fixture.identity,
            fixture.user_id,
            1,
            &fixture.genesis_capability,
            &rotated_history,
            Some(&fixture.capsule_one),
            &fixture.capsule_two,
        )
        .expect("应打开最近轮换直接前驱与当前两代 capsule");
        assert_eq!(opened.current.key_epoch, 2);
        assert_eq!(opened.current.ark.as_bytes(), fixture.epoch_two.as_bytes());
        let source = opened.source.expect("轮换历史应返回源 ARK");
        assert_eq!(source.key_epoch, 1);
        assert_eq!(source.ark.as_bytes(), fixture.epoch_one.as_bytes());

        assert_eq!(
            verify_recovery_history_and_open_capsules(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &rotated_history,
                Some(&fixture.capsule_two),
                &fixture.capsule_two,
            )
            .err()
            .expect("源 capsule 必须精确绑定轮换直接前驱"),
            RecoveryCryptoError::MembershipHistoryHeadMismatch
        );
        assert_eq!(
            verify_recovery_history_and_open_capsules(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &rotated_history,
                None,
                &fixture.capsule_two,
            )
            .err()
            .expect("epoch 大于一时不得省略源 capsule"),
            RecoveryCryptoError::MembershipHistoryHeadMismatch
        );
    }

    #[test]
    fn recovery_history_accepts_resume_replace_and_direct_replace() {
        let fixture = RecoveryHistoryFixture::new();
        let recovered_history = fixture.history(&[
            fixture.add_device.as_slice(),
            fixture.revoke_rotate.as_slice(),
            fixture.recover_resume.as_slice(),
            fixture.recover_replace.as_slice(),
        ]);
        let opened_pending = verify_recovery_history_and_open_capsules(
            &fixture.identity,
            fixture.user_id,
            1,
            &fixture.genesis_capability,
            &recovered_history,
            Some(&fixture.capsule_two),
            &fixture.capsule_three,
        )
        .expect("resume/replace 历史应打开相邻两代 capsule");
        assert_eq!(opened_pending.current.key_epoch, 3);
        assert_eq!(
            opened_pending.current.ark.as_bytes(),
            fixture.epoch_three.as_bytes()
        );
        assert_eq!(
            opened_pending
                .source
                .expect("replace pending 应返回源 ARK")
                .ark
                .as_bytes(),
            fixture.epoch_two.as_bytes()
        );

        let direct_replace = build_recover_replace_manifest(
            &fixture.genesis,
            &fixture.epoch_one,
            &fixture.epoch_two,
            fixture.user_id,
            &fixture.capsule_two,
            Some((0x75, 0x76)),
        );
        let direct_history = fixture.history(&[&direct_replace]);
        let opened_direct = verify_recovery_history_and_open_capsules(
            &fixture.identity,
            fixture.user_id,
            1,
            &fixture.genesis_capability,
            &direct_history,
            Some(&fixture.capsule_one),
            &fixture.capsule_two,
        )
        .expect("新材料直接 replace 应打开相邻两代");
        assert_eq!(opened_direct.current.key_epoch, 2);
        assert_eq!(
            opened_direct
                .source
                .expect("直接 replace 必须保留前一代")
                .key_epoch,
            1
        );
    }

    #[test]
    fn recovery_history_rejects_replayed_resume_and_accepts_valid_post_rotation_add() {
        let fixture = RecoveryHistoryFixture::new();
        let mut second_resume = build_recover_resume_manifest(
            &fixture.recover_resume,
            &fixture.epoch_two,
            fixture.user_id,
            0x75,
            0x76,
        );
        second_resume[176..192].copy_from_slice(&fixture.recover_resume[176..192]);
        sign_history_manifest(
            &mut second_resume,
            fixture.user_id,
            None,
            (&fixture.epoch_two, 2),
        );
        let replayed_history = fixture.history(&[
            &fixture.add_device,
            &fixture.revoke_rotate,
            &fixture.recover_resume,
            &second_resume,
        ]);
        assert_eq!(
            verify_recovery_history_and_open_capsules(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &replayed_history,
                Some(&fixture.capsule_one),
                &fixture.capsule_two,
            )
            .err()
            .expect("重复 operationId 必须失败"),
            RecoveryCryptoError::MembershipHistoryTransitionInvalid
        );

        let mut ordinary_add = build_recover_resume_manifest(
            &fixture.revoke_rotate,
            &fixture.epoch_two,
            fixture.user_id,
            0x77,
            0x78,
        );
        ordinary_add[172..176].copy_from_slice(&2_u32.to_be_bytes());
        ordinary_add[192..208].copy_from_slice(&fixture.revoke_rotate[260..276]);
        sign_history_manifest(
            &mut ordinary_add,
            fixture.user_id,
            None,
            (&fixture.epoch_two, 2),
        );
        let ordinary_add_history =
            fixture.history(&[&fixture.add_device, &fixture.revoke_rotate, &ordinary_add]);
        verify_recovery_history_and_open_capsules(
            &fixture.identity,
            fixture.user_id,
            1,
            &fixture.genesis_capability,
            &ordinary_add_history,
            Some(&fixture.capsule_one),
            &fixture.capsule_two,
        )
        .expect("不依赖未签名 phase 时，合法轮换后 addDevice 仍应可恢复");
    }

    #[test]
    fn recovery_history_enforces_operation_authorization_digest_by_operation() {
        let fixture = RecoveryHistoryFixture::new();

        let mut invalid_genesis = fixture.genesis;
        invalid_genesis[224] = 1;
        sign_history_manifest(
            &mut invalid_genesis,
            fixture.user_id,
            None,
            (&fixture.epoch_one, 1),
        );
        assert_eq!(
            validate_genesis(
                &invalid_genesis,
                fixture.user_id,
                1,
                fixture.identity.public_key().expect("恢复公钥应派生"),
            ),
            Err(RecoveryCryptoError::InvalidGenesis)
        );

        let mut invalid_add = fixture.add_device.clone();
        invalid_add[224] = 1;
        sign_history_manifest(
            &mut invalid_add,
            fixture.user_id,
            None,
            (&fixture.epoch_one, 1),
        );
        let invalid_add_history = fixture.history(&[&invalid_add]);
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &invalid_add_history,
                &fixture.capsule_one,
            )
            .err()
            .expect("新增设备不得携带操作授权摘要"),
            RecoveryCryptoError::MembershipHistoryTransitionInvalid
        );

        let mut authorized_rotate = fixture.revoke_rotate.clone();
        authorized_rotate[224..256].fill(0xa5);
        sign_history_manifest(
            &mut authorized_rotate,
            fixture.user_id,
            Some((&fixture.epoch_one, 1)),
            (&fixture.epoch_two, 2),
        );
        let authorized_rotate_history = fixture.history(&[&fixture.add_device, &authorized_rotate]);
        verify_recovery_history_and_open_capsules(
            &fixture.identity,
            fixture.user_id,
            1,
            &fixture.genesis_capability,
            &authorized_rotate_history,
            Some(&fixture.capsule_one),
            &fixture.capsule_two,
        )
        .expect("撤销轮换应允许签名覆盖的自撤销 intent 摘要");

        let mut invalid_resume = fixture.recover_resume.clone();
        invalid_resume[224] = 1;
        sign_history_manifest(
            &mut invalid_resume,
            fixture.user_id,
            None,
            (&fixture.epoch_two, 2),
        );
        let invalid_resume_history =
            fixture.history(&[&fixture.add_device, &fixture.revoke_rotate, &invalid_resume]);
        assert_eq!(
            verify_recovery_history_and_open_capsules(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &invalid_resume_history,
                Some(&fixture.capsule_one),
                &fixture.capsule_two,
            )
            .err()
            .expect("恢复接续不得携带操作授权摘要"),
            RecoveryCryptoError::MembershipHistoryTransitionInvalid
        );

        let mut invalid_replace = fixture.recover_replace.clone();
        invalid_replace[224] = 1;
        sign_history_manifest(
            &mut invalid_replace,
            fixture.user_id,
            Some((&fixture.epoch_two, 2)),
            (&fixture.epoch_three, 3),
        );
        let invalid_replace_history = fixture.history(&[
            &fixture.add_device,
            &fixture.revoke_rotate,
            &fixture.recover_resume,
            &invalid_replace,
        ]);
        assert_eq!(
            verify_recovery_history_and_open_capsules(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &invalid_replace_history,
                Some(&fixture.capsule_two),
                &fixture.capsule_three,
            )
            .err()
            .expect("恢复替换不得携带操作授权摘要"),
            RecoveryCryptoError::MembershipHistoryTransitionInvalid
        );
    }

    #[test]
    fn recovery_history_rejects_anchor_skip_fork_and_malformed_members() {
        let fixture = RecoveryHistoryFixture::new();

        let mut wrong_anchor = fixture.history(&[]);
        wrong_anchor[20] ^= 1;
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &wrong_anchor,
                &fixture.capsule_one,
            )
            .err()
            .expect("错配 genesis 锚必须失败"),
            RecoveryCryptoError::MembershipHistoryAnchorMismatch
        );

        let mut skipped = fixture.add_device.clone();
        skipped[28..32].copy_from_slice(&3_u32.to_be_bytes());
        sign_history_manifest(&mut skipped, fixture.user_id, None, (&fixture.epoch_one, 1));
        let skipped_history = fixture.history(&[&skipped]);
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &skipped_history,
                &fixture.capsule_one,
            )
            .err()
            .expect("跳代历史必须失败"),
            RecoveryCryptoError::MembershipHistoryTransitionInvalid
        );

        let mut forked = fixture.add_device.clone();
        forked[36] ^= 1;
        sign_history_manifest(&mut forked, fixture.user_id, None, (&fixture.epoch_one, 1));
        let forked_history = fixture.history(&[&forked]);
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &forked_history,
                &fixture.capsule_one,
            )
            .err()
            .expect("分叉历史必须失败"),
            RecoveryCryptoError::MembershipHistoryTransitionInvalid
        );

        let mut unordered = fixture.add_device.clone();
        let first_member: [u8; 88] = copy_array(&unordered[260..348]);
        let second_member: [u8; 88] = copy_array(&unordered[348..436]);
        unordered[260..348].copy_from_slice(&second_member);
        unordered[348..436].copy_from_slice(&first_member);
        sign_history_manifest(
            &mut unordered,
            fixture.user_id,
            None,
            (&fixture.epoch_one, 1),
        );
        let unordered_history = fixture.history(&[&unordered]);
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &unordered_history,
                &fixture.capsule_one,
            )
            .err()
            .expect("非规范成员顺序必须失败"),
            RecoveryCryptoError::InvalidMembershipHistory
        );

        let truncated = fixture.history(&[&fixture.add_device[..fixture.add_device.len() - 1]]);
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &truncated,
                &fixture.capsule_one,
            )
            .err()
            .expect("截断成员历史必须失败"),
            RecoveryCryptoError::InvalidMembershipHistory
        );
    }

    #[test]
    fn recovery_history_rejects_state_replacement_and_signature_attacks() {
        let fixture = RecoveryHistoryFixture::new();

        let mut replaced_recovery_state = fixture.add_device.clone();
        replaced_recovery_state[100..104].copy_from_slice(&2_u32.to_be_bytes());
        sign_history_manifest(
            &mut replaced_recovery_state,
            fixture.user_id,
            None,
            (&fixture.epoch_one, 1),
        );
        let replaced_history = fixture.history(&[&replaced_recovery_state]);
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &replaced_history,
                &fixture.capsule_one,
            )
            .err()
            .expect("add 不得替换恢复状态"),
            RecoveryCryptoError::MembershipHistoryTransitionInvalid
        );

        let mut add_with_transition = fixture.add_device.clone();
        sign_history_manifest(
            &mut add_with_transition,
            fixture.user_id,
            Some((&fixture.epoch_one, 1)),
            (&fixture.epoch_one, 1),
        );
        let add_with_transition_history = fixture.history(&[&add_with_transition]);
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &add_with_transition_history,
                &fixture.capsule_one,
            )
            .err()
            .expect("add 不得携带 transition 签名"),
            RecoveryCryptoError::MembershipHistoryTransitionInvalid
        );

        let mut invalid_transition = fixture.revoke_rotate.clone();
        let revoke_payload_length = invalid_transition.len() - 128;
        invalid_transition[revoke_payload_length] ^= 1;
        let invalid_transition_history =
            fixture.history(&[&fixture.add_device, &invalid_transition]);
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &invalid_transition_history,
                &fixture.capsule_two,
            )
            .err()
            .expect("伪造旧 epoch 过渡签名必须失败"),
            RecoveryCryptoError::MembershipHistorySignatureInvalid
        );

        let mut invalid_current = fixture.revoke_rotate.clone();
        let last = invalid_current.len() - 1;
        invalid_current[last] ^= 1;
        let invalid_current_history = fixture.history(&[&fixture.add_device, &invalid_current]);
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &invalid_current_history,
                &fixture.capsule_two,
            )
            .err()
            .expect("伪造新 epoch 当前签名必须失败"),
            RecoveryCryptoError::MembershipHistorySignatureInvalid
        );

        let full_history = fixture.history(&[&fixture.add_device, &fixture.revoke_rotate]);
        assert_eq!(
            verify_recovery_history_and_open_current_capsule(
                &fixture.identity,
                fixture.user_id,
                1,
                &fixture.genesis_capability,
                &full_history,
                &fixture.capsule_one,
            )
            .err()
            .expect("链头不得打开旧 capsule"),
            RecoveryCryptoError::MembershipHistoryHeadMismatch
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
            RecoveryMedia::from_bytes(&[0_u8; 644]),
            Err(RecoveryCryptoError::InvalidMediaLength {
                expected: 676,
                actual: 644,
            })
        );
        let mut legacy_magic = [0_u8; RECOVERY_MEDIA_LENGTH];
        encode_media_header(&mut legacy_magic[..RECOVERY_MEDIA_HEADER_LENGTH]);
        legacy_magic[..8].copy_from_slice(b"KELVRM01");
        assert_eq!(
            RecoveryMedia::from_bytes(&legacy_magic),
            Err(RecoveryCryptoError::InvalidMediaMagic)
        );
        let mut legacy_version = [0_u8; RECOVERY_MEDIA_LENGTH];
        encode_media_header(&mut legacy_version[..RECOVERY_MEDIA_HEADER_LENGTH]);
        legacy_version[8..10].copy_from_slice(&1_u16.to_be_bytes());
        assert_eq!(
            RecoveryMedia::from_bytes(&legacy_version),
            Err(RecoveryCryptoError::UnsupportedMediaVersion(1))
        );
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
