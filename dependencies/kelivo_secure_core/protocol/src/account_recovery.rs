//! 账户恢复 challenge、证明与提交准备的唯一 v1 协议实现。

use std::fmt;

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
use zeroize::{Zeroize, Zeroizing};

use crate::{
    device_crypto::{
        ACCOUNT_TRUST_SIGNATURE_LENGTH, ARK_ENVELOPE_LENGTH, AccountRootKey,
        AccountTrustBinding, ArkEnvelope, ArkEnvelopeBinding, DeviceId,
        DeviceKeyAgreementPublicKey, DevicePublicKeys, DeviceSigningPublicKey, HpkeRngAdapter,
        UserId, derive_account_trust_public_key, sign_account_trust_payload,
    },
    recovery_crypto::{
        RECOVERY_CAPSULE_LENGTH, RecoveryCapsule, RecoveryHistoryMember, RecoveryIdentity,
        RecoveryPublicKey, VerifiedRecoveryHistoryHead, seal_recovery_capsule,
    },
};

const CHALLENGE_MAGIC: [u8; 8] = *b"KELIVORC";
const SEALED_NONCE_MAGIC: [u8; 8] = *b"KELIVORS";
const PROOF_MAGIC: [u8; 8] = *b"KELIVORP";
const HPKE_INFO_DOMAIN: &[u8] = b"kelivo.account-recovery.hpke-info.v1\0";
const HPKE_AAD_DOMAIN: &[u8] = b"kelivo.account-recovery.challenge-aad.v1\0";
const TRUST_SIGNATURE_DOMAIN: &[u8] = b"kelivo.account-recovery.trust-signature.v1\0";

pub const ACCOUNT_RECOVERY_PROTOCOL_VERSION: u32 = 1;
pub const ACCOUNT_RECOVERY_CHALLENGE_LENGTH: usize = 316;
pub const ACCOUNT_RECOVERY_SEALED_NONCE_LENGTH: usize = 100;
pub const ACCOUNT_RECOVERY_PROOF_TRANSCRIPT_LENGTH: usize = 108;
pub const ACCOUNT_RECOVERY_NONCE_LENGTH: usize = 32;
pub const ACCOUNT_RECOVERY_TOKEN_DIGEST_LENGTH: usize = 32;
pub const ACCOUNT_RECOVERY_NONCE_PROOF_LENGTH: usize = 32;
const HPKE_KEM_ID: u16 = 0x0020;
const HPKE_KDF_ID: u16 = 0x0001;
const HPKE_AEAD_ID: u16 = 0x0003;
const SEALED_NONCE_HEADER_LENGTH: usize = 20;
const HPKE_ENCAPSULATED_KEY_LENGTH: usize = 32;
const HPKE_CIPHERTEXT_LENGTH: usize = ACCOUNT_RECOVERY_NONCE_LENGTH;
const HPKE_TAG_LENGTH: usize = 16;
const SEALED_NONCE_ENCAPSULATED_KEY_OFFSET: usize = SEALED_NONCE_HEADER_LENGTH;
const SEALED_NONCE_CIPHERTEXT_OFFSET: usize =
    SEALED_NONCE_ENCAPSULATED_KEY_OFFSET + HPKE_ENCAPSULATED_KEY_LENGTH;
const SEALED_NONCE_TAG_OFFSET: usize =
    SEALED_NONCE_CIPHERTEXT_OFFSET + HPKE_CIPHERTEXT_LENGTH;

const CHALLENGE_ATTEMPT_OFFSET: usize = 20;
const CHALLENGE_USER_OFFSET: usize = 36;
const CHALLENGE_DEVICE_OFFSET: usize = 52;
const CHALLENGE_DEVICE_KEY_VERSION_OFFSET: usize = 68;
const CHALLENGE_DEVICE_SIGNING_KEY_OFFSET: usize = 72;
const CHALLENGE_DEVICE_AGREEMENT_KEY_OFFSET: usize = 104;
const CHALLENGE_SECURITY_GENERATION_OFFSET: usize = 136;
const CHALLENGE_KEY_EPOCH_OFFSET: usize = 140;
const CHALLENGE_MEMBERSHIP_DIGEST_OFFSET: usize = 144;
const CHALLENGE_RECOVERY_KEY_VERSION_OFFSET: usize = 176;
const CHALLENGE_RECOVERY_KEY_OFFSET: usize = 180;
const CHALLENGE_CAPSULE_VERSION_OFFSET: usize = 212;
const CHALLENGE_CAPSULE_DIGEST_OFFSET: usize = 216;
const CHALLENGE_DATA_PHASE_OFFSET: usize = 248;
const CHALLENGE_SOURCE_DATA_GENERATION_OFFSET: usize = 252;
const CHALLENGE_SOURCE_DATA_KEY_EPOCH_OFFSET: usize = 256;
const CHALLENGE_SOURCE_REKEY_OPERATION_OFFSET: usize = 260;
const CHALLENGE_EXPIRES_AT_OFFSET: usize = 276;
const CHALLENGE_REQUEST_DIGEST_OFFSET: usize = 284;

const MEMBERSHIP_MAGIC: [u8; 8] = *b"KELIVOMM";
const MEMBERSHIP_FORMAT_VERSION: u32 = 1;
const MEMBERSHIP_HEADER_LENGTH: usize = 228;
const MEMBERSHIP_MEMBER_LENGTH: usize = 88;
const MEMBERSHIP_SIGNATURE_SECTION_LENGTH: usize = ACCOUNT_TRUST_SIGNATURE_LENGTH * 2;
const MEMBERSHIP_MAX_MEMBERS: usize = 256;
const RESUME_REQUEST_DIGEST_DOMAIN: &[u8] = b"kelivo.account-recovery.resume-commit.v1\0";
const REPLACEMENT_REQUEST_DIGEST_DOMAIN: &[u8] =
    b"kelivo.account-recovery.replacement-commit.v1\0";

const _: () = {
    assert!(SEALED_NONCE_TAG_OFFSET + HPKE_TAG_LENGTH == ACCOUNT_RECOVERY_SEALED_NONCE_LENGTH);
    assert!(CHALLENGE_REQUEST_DIGEST_OFFSET + 32 == ACCOUNT_RECOVERY_CHALLENGE_LENGTH);
    assert!(8 + 4 + 32 + 32 + 32 == ACCOUNT_RECOVERY_PROOF_TRANSCRIPT_LENGTH);
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AccountRecoveryDataPhase {
    Ready,
    RekeyPending,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AccountRecoveryProtocolError {
    InvalidChallengeLength { actual: usize },
    InvalidChallengeHeader,
    InvalidChallengeBinding,
    InvalidChallengeCounter,
    InvalidChallengeState,
    InvalidSealedNonceLength { actual: usize },
    InvalidSealedNonceHeader,
    InvalidSealedNonceKey,
    SealedNonceAuthenticationFailed,
    InvalidProofInput,
    RandomnessUnavailable,
    SealedNonceCreationFailed,
    InvalidPrepareInput,
    PrepareBindingMismatch,
    PrepareCryptoFailed,
}

impl fmt::Display for AccountRecoveryProtocolError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidChallengeLength { actual } => {
                write!(formatter, "账户恢复 challenge 长度无效：{actual}")
            }
            Self::InvalidChallengeHeader => formatter.write_str("账户恢复 challenge 头无效"),
            Self::InvalidChallengeBinding => formatter.write_str("账户恢复 challenge 绑定不一致"),
            Self::InvalidChallengeCounter => formatter.write_str("账户恢复 challenge 计数器无效"),
            Self::InvalidChallengeState => formatter.write_str("账户恢复 challenge 状态无效"),
            Self::InvalidSealedNonceLength { actual } => {
                write!(formatter, "账户恢复 sealed nonce 长度无效：{actual}")
            }
            Self::InvalidSealedNonceHeader => formatter.write_str("账户恢复 sealed nonce 头无效"),
            Self::InvalidSealedNonceKey => formatter.write_str("账户恢复 sealed nonce 密钥无效"),
            Self::SealedNonceAuthenticationFailed => {
                formatter.write_str("账户恢复 sealed nonce 认证失败")
            }
            Self::InvalidProofInput => formatter.write_str("账户恢复 proof 输入无效"),
            Self::RandomnessUnavailable => formatter.write_str("账户恢复随机源不可用"),
            Self::SealedNonceCreationFailed => formatter.write_str("账户恢复 sealed nonce 创建失败"),
            Self::InvalidPrepareInput => formatter.write_str("账户恢复提交准备输入无效"),
            Self::PrepareBindingMismatch => formatter.write_str("账户恢复提交准备绑定不一致"),
            Self::PrepareCryptoFailed => formatter.write_str("账户恢复提交准备密码学操作失败"),
        }
    }
}

impl std::error::Error for AccountRecoveryProtocolError {}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AccountRecoveryChallengeExpectation {
    pub attempt_id: [u8; 16],
    pub user_id: UserId,
    pub device_id: DeviceId,
    pub device_key_version: u32,
    pub device_public_keys: DevicePublicKeys,
    pub security_generation: u32,
    pub key_epoch: u32,
    pub membership_manifest_digest: [u8; 32],
    pub recovery_public_key_version: u32,
    pub recovery_public_key: RecoveryPublicKey,
    pub recovery_capsule_version: u32,
    pub recovery_capsule_digest: [u8; 32],
    pub expires_at_ms: u64,
    pub request_digest: [u8; 32],
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct VerifiedAccountRecoveryChallenge {
    pub attempt_id: [u8; 16],
    pub user_id: UserId,
    pub device_id: DeviceId,
    pub device_key_version: u32,
    pub device_public_keys: DevicePublicKeys,
    pub security_generation: u32,
    pub key_epoch: u32,
    pub membership_manifest_digest: [u8; 32],
    pub recovery_public_key_version: u32,
    pub recovery_public_key: RecoveryPublicKey,
    pub recovery_capsule_version: u32,
    pub recovery_capsule_digest: [u8; 32],
    pub data_phase: AccountRecoveryDataPhase,
    pub source_data_generation: u32,
    pub source_data_key_epoch: u32,
    pub source_data_rekey_operation_id: Option<[u8; 16]>,
    pub expires_at_ms: u64,
    pub request_digest: [u8; 32],
    bytes: [u8; ACCOUNT_RECOVERY_CHALLENGE_LENGTH],
}

impl VerifiedAccountRecoveryChallenge {
    pub fn parse_and_bind(
        frame: &[u8],
        expected: AccountRecoveryChallengeExpectation,
    ) -> Result<Self, AccountRecoveryProtocolError> {
        if frame.len() != ACCOUNT_RECOVERY_CHALLENGE_LENGTH {
            return Err(AccountRecoveryProtocolError::InvalidChallengeLength {
                actual: frame.len(),
            });
        }
        if frame[..8] != CHALLENGE_MAGIC
            || read_u32(frame, 8) != ACCOUNT_RECOVERY_PROTOCOL_VERSION
            || read_u16(frame, 12) != HPKE_KEM_ID
            || read_u16(frame, 14) != HPKE_KDF_ID
            || read_u16(frame, 16) != HPKE_AEAD_ID
            || read_u16(frame, 18) != 0
        {
            return Err(AccountRecoveryProtocolError::InvalidChallengeHeader);
        }

        let attempt_id = copy_array(&frame[CHALLENGE_ATTEMPT_OFFSET..CHALLENGE_USER_OFFSET]);
        require_uuid_v4(&attempt_id)?;
        let user_id = UserId::new(copy_array(
            &frame[CHALLENGE_USER_OFFSET..CHALLENGE_DEVICE_OFFSET],
        ))
        .map_err(|_| AccountRecoveryProtocolError::InvalidChallengeBinding)?;
        let device_id = DeviceId::new(copy_array(
            &frame[CHALLENGE_DEVICE_OFFSET..CHALLENGE_DEVICE_KEY_VERSION_OFFSET],
        ))
        .map_err(|_| AccountRecoveryProtocolError::InvalidChallengeBinding)?;
        let device_key_version = read_u32(frame, CHALLENGE_DEVICE_KEY_VERSION_OFFSET);
        let device_public_keys = DevicePublicKeys {
            signing: DeviceSigningPublicKey::from_bytes(copy_array(
                &frame[CHALLENGE_DEVICE_SIGNING_KEY_OFFSET
                    ..CHALLENGE_DEVICE_AGREEMENT_KEY_OFFSET],
            ))
            .map_err(|_| AccountRecoveryProtocolError::InvalidChallengeBinding)?,
            key_agreement: DeviceKeyAgreementPublicKey::from_bytes(copy_array(
                &frame[CHALLENGE_DEVICE_AGREEMENT_KEY_OFFSET
                    ..CHALLENGE_SECURITY_GENERATION_OFFSET],
            ))
            .map_err(|_| AccountRecoveryProtocolError::InvalidChallengeBinding)?,
        };
        let security_generation = read_u32(frame, CHALLENGE_SECURITY_GENERATION_OFFSET);
        let key_epoch = read_u32(frame, CHALLENGE_KEY_EPOCH_OFFSET);
        let membership_manifest_digest = copy_array(
            &frame[CHALLENGE_MEMBERSHIP_DIGEST_OFFSET..CHALLENGE_RECOVERY_KEY_VERSION_OFFSET],
        );
        let recovery_public_key_version = read_u32(frame, CHALLENGE_RECOVERY_KEY_VERSION_OFFSET);
        let recovery_public_key = RecoveryPublicKey::from_bytes(copy_array(
            &frame[CHALLENGE_RECOVERY_KEY_OFFSET..CHALLENGE_CAPSULE_VERSION_OFFSET],
        ))
        .map_err(|_| AccountRecoveryProtocolError::InvalidChallengeBinding)?;
        let recovery_capsule_version = read_u32(frame, CHALLENGE_CAPSULE_VERSION_OFFSET);
        let recovery_capsule_digest = copy_array(
            &frame[CHALLENGE_CAPSULE_DIGEST_OFFSET..CHALLENGE_DATA_PHASE_OFFSET],
        );
        if device_key_version == 0
            || security_generation == 0
            || security_generation > 0x7fff_ffff
            || key_epoch == 0
            || recovery_public_key_version == 0
            || recovery_public_key_version > 0x7fff_ffff
            || recovery_capsule_version == 0
            || recovery_capsule_version > 0x7fff_ffff
        {
            return Err(AccountRecoveryProtocolError::InvalidChallengeCounter);
        }
        if frame[CHALLENGE_DATA_PHASE_OFFSET + 1..CHALLENGE_SOURCE_DATA_GENERATION_OFFSET]
            .iter()
            .any(|byte| *byte != 0)
        {
            return Err(AccountRecoveryProtocolError::InvalidChallengeState);
        }
        let source_data_generation = read_u32(frame, CHALLENGE_SOURCE_DATA_GENERATION_OFFSET);
        let source_data_key_epoch = read_u32(frame, CHALLENGE_SOURCE_DATA_KEY_EPOCH_OFFSET);
        let source_operation = copy_array(
            &frame[CHALLENGE_SOURCE_REKEY_OPERATION_OFFSET..CHALLENGE_EXPIRES_AT_OFFSET],
        );
        let (data_phase, source_data_rekey_operation_id) = match frame[CHALLENGE_DATA_PHASE_OFFSET]
        {
            0 if source_operation == [0; 16] => (AccountRecoveryDataPhase::Ready, None),
            1 if source_operation != [0; 16] => {
                require_uuid_v4(&source_operation)?;
                (AccountRecoveryDataPhase::RekeyPending, Some(source_operation))
            }
            _ => return Err(AccountRecoveryProtocolError::InvalidChallengeState),
        };
        if source_data_generation == 0
            || source_data_generation > 0x7fff_ffff
            || source_data_key_epoch == 0
        {
            return Err(AccountRecoveryProtocolError::InvalidChallengeCounter);
        }
        let expires_at_ms = read_u64(frame, CHALLENGE_EXPIRES_AT_OFFSET);
        if expires_at_ms == 0 {
            return Err(AccountRecoveryProtocolError::InvalidChallengeState);
        }
        let request_digest = copy_array(&frame[CHALLENGE_REQUEST_DIGEST_OFFSET..]);

        let actual = Self {
            attempt_id,
            user_id,
            device_id,
            device_key_version,
            device_public_keys,
            security_generation,
            key_epoch,
            membership_manifest_digest,
            recovery_public_key_version,
            recovery_public_key,
            recovery_capsule_version,
            recovery_capsule_digest,
            data_phase,
            source_data_generation,
            source_data_key_epoch,
            source_data_rekey_operation_id,
            expires_at_ms,
            request_digest,
            bytes: copy_array(frame),
        };
        if actual.attempt_id != expected.attempt_id
            || actual.user_id != expected.user_id
            || actual.device_id != expected.device_id
            || actual.device_key_version != expected.device_key_version
            || actual.device_public_keys != expected.device_public_keys
            || actual.security_generation != expected.security_generation
            || actual.key_epoch != expected.key_epoch
            || actual.membership_manifest_digest != expected.membership_manifest_digest
            || actual.recovery_public_key_version != expected.recovery_public_key_version
            || actual.recovery_public_key != expected.recovery_public_key
            || actual.recovery_capsule_version != expected.recovery_capsule_version
            || actual.recovery_capsule_digest != expected.recovery_capsule_digest
            || actual.expires_at_ms != expected.expires_at_ms
            || actual.request_digest != expected.request_digest
        {
            return Err(AccountRecoveryProtocolError::InvalidChallengeBinding);
        }
        Ok(actual)
    }

    pub const fn as_bytes(&self) -> &[u8; ACCOUNT_RECOVERY_CHALLENGE_LENGTH] {
        &self.bytes
    }
}

pub struct AccountRecoveryProofMaterial {
    pub transcript: [u8; ACCOUNT_RECOVERY_PROOF_TRANSCRIPT_LENGTH],
    pub nonce_proof: [u8; ACCOUNT_RECOVERY_NONCE_PROOF_LENGTH],
    pub trust_signature_message: [u8; 32],
}

impl Zeroize for AccountRecoveryProofMaterial {
    fn zeroize(&mut self) {
        self.transcript.zeroize();
        self.nonce_proof.zeroize();
        self.trust_signature_message.zeroize();
    }
}

impl Drop for AccountRecoveryProofMaterial {
    fn drop(&mut self) {
        self.zeroize();
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AccountRecoveryCommitKind {
    Resume,
    Replacement,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AccountRecoveryPrepareInput {
    pub kind: AccountRecoveryCommitKind,
    pub operation_id: [u8; 16],
    pub target_auth_generation: u32,
    pub rekey_operation_id: Option<[u8; 16]>,
    pub completion_session_id: Option<[u8; 16]>,
    pub completion_session_token_digest: Option<[u8; 32]>,
}

pub struct PreparedAccountRecoveryCommit {
    pub kind: AccountRecoveryCommitKind,
    pub expected_generation: u32,
    pub expected_key_epoch: u32,
    pub next_generation: u32,
    pub next_key_epoch: u32,
    pub operation_id: [u8; 16],
    pub manifest: Vec<u8>,
    pub manifest_digest: [u8; 32],
    pub envelope: ArkEnvelope,
    pub next_recovery_capsule: Option<RecoveryCapsule>,
    pub next_ark: Option<AccountRootKey>,
    pub request_digest: [u8; 32],
}

pub fn prepare_account_recovery_commit<R>(
    rng: &mut R,
    current_ark: &AccountRootKey,
    device_identity: &crate::device_crypto::DeviceIdentity,
    challenge: &VerifiedAccountRecoveryChallenge,
    history_head: &VerifiedRecoveryHistoryHead,
    input: AccountRecoveryPrepareInput,
) -> Result<PreparedAccountRecoveryCommit, AccountRecoveryProtocolError>
where
    R: CryptoRng + RngCore,
{
    validate_prepare_binding(device_identity, challenge, history_head, input)?;
    let next_generation = history_head
        .security_generation
        .checked_add(1)
        .filter(|value| *value <= 0x7fff_ffff)
        .ok_or(AccountRecoveryProtocolError::InvalidPrepareInput)?;
    let target = RecoveryHistoryMember {
        device_id: challenge.device_id,
        key_version: challenge.device_key_version,
        auth_generation: input.target_auth_generation,
        signing_public_key: challenge.device_public_keys.signing,
        key_agreement_public_key: challenge.device_public_keys.key_agreement,
    };

    match input.kind {
        AccountRecoveryCommitKind::Resume => {
            let mut members = history_head.members.clone();
            members.push(target);
            members.sort_by(|left, right| left.device_id.as_bytes().cmp(right.device_id.as_bytes()));
            let manifest = build_membership_manifest(
                history_head,
                next_generation,
                history_head.key_epoch,
                history_head.current_trust_public_key,
                history_head.recovery_capsule_version,
                history_head.recovery_capsule_digest,
                4,
                input.operation_id,
                target.device_id,
                &members,
                None,
                (current_ark, history_head.key_epoch),
            )?;
            let envelope = device_identity
                .seal_ark_envelope(
                    rng,
                    current_ark,
                    self_envelope_binding(challenge, history_head.key_epoch),
                )
                .map_err(|_| AccountRecoveryProtocolError::PrepareCryptoFailed)?;
            let manifest_digest = Sha256::digest(&manifest).into();
            let request_digest = commit_request_digest(
                challenge,
                input,
                history_head,
                &manifest,
                &manifest_digest,
                history_head.key_epoch,
                envelope.as_bytes(),
                None,
            )?;
            Ok(PreparedAccountRecoveryCommit {
                kind: input.kind,
                expected_generation: history_head.security_generation,
                expected_key_epoch: history_head.key_epoch,
                next_generation,
                next_key_epoch: history_head.key_epoch,
                operation_id: input.operation_id,
                manifest,
                manifest_digest,
                envelope,
                next_recovery_capsule: None,
                next_ark: None,
                request_digest,
            })
        }
        AccountRecoveryCommitKind::Replacement => {
            let next_key_epoch = history_head
                .key_epoch
                .checked_add(1)
                .ok_or(AccountRecoveryProtocolError::InvalidPrepareInput)?;
            let next_capsule_version = history_head
                .recovery_capsule_version
                .checked_add(1)
                .filter(|value| *value <= 0x7fff_ffff)
                .ok_or(AccountRecoveryProtocolError::InvalidPrepareInput)?;
            let next_ark = AccountRootKey::generate(rng)
                .map_err(|_| AccountRecoveryProtocolError::PrepareCryptoFailed)?;
            let next_capsule = seal_recovery_capsule(
                rng,
                &next_ark,
                history_head.user_id,
                next_key_epoch,
                history_head.recovery_public_key_version,
                next_capsule_version,
                history_head.recovery_public_key,
            )
            .map_err(|_| AccountRecoveryProtocolError::PrepareCryptoFailed)?;
            let next_capsule_digest = Sha256::digest(next_capsule.as_bytes()).into();
            let next_trust_public_key = derive_account_trust_public_key(
                &next_ark,
                AccountTrustBinding {
                    user_id: history_head.user_id,
                    key_epoch: next_key_epoch,
                },
            )
            .map_err(|_| AccountRecoveryProtocolError::PrepareCryptoFailed)?;
            let manifest = build_membership_manifest(
                history_head,
                next_generation,
                next_key_epoch,
                next_trust_public_key,
                next_capsule_version,
                next_capsule_digest,
                5,
                input.operation_id,
                target.device_id,
                &[target],
                Some((current_ark, history_head.key_epoch)),
                (&next_ark, next_key_epoch),
            )?;
            let envelope = device_identity
                .seal_ark_envelope(
                    rng,
                    &next_ark,
                    self_envelope_binding(challenge, next_key_epoch),
                )
                .map_err(|_| AccountRecoveryProtocolError::PrepareCryptoFailed)?;
            let manifest_digest = Sha256::digest(&manifest).into();
            let request_digest = commit_request_digest(
                challenge,
                input,
                history_head,
                &manifest,
                &manifest_digest,
                next_key_epoch,
                envelope.as_bytes(),
                Some((next_capsule_version, next_capsule.as_bytes())),
            )?;
            Ok(PreparedAccountRecoveryCommit {
                kind: input.kind,
                expected_generation: history_head.security_generation,
                expected_key_epoch: history_head.key_epoch,
                next_generation,
                next_key_epoch,
                operation_id: input.operation_id,
                manifest,
                manifest_digest,
                envelope,
                next_recovery_capsule: Some(next_capsule),
                next_ark: Some(next_ark),
                request_digest,
            })
        }
    }
}

fn validate_prepare_binding(
    device_identity: &crate::device_crypto::DeviceIdentity,
    challenge: &VerifiedAccountRecoveryChallenge,
    history_head: &VerifiedRecoveryHistoryHead,
    input: AccountRecoveryPrepareInput,
) -> Result<(), AccountRecoveryProtocolError> {
    require_uuid_v4(&input.operation_id)?;
    if input.target_auth_generation == 0
        || input.target_auth_generation > 0x7fff_ffff
        || history_head.user_id != challenge.user_id
        || history_head.security_generation != challenge.security_generation
        || history_head.key_epoch != challenge.key_epoch
        || history_head.digest != challenge.membership_manifest_digest
        || history_head.recovery_public_key_version != challenge.recovery_public_key_version
        || history_head.recovery_public_key != challenge.recovery_public_key
        || history_head.recovery_capsule_version != challenge.recovery_capsule_version
        || history_head.recovery_capsule_digest != challenge.recovery_capsule_digest
        || device_identity.public_keys() != challenge.device_public_keys
        || history_head.operation_ids.contains(&input.operation_id)
    {
        return Err(AccountRecoveryProtocolError::PrepareBindingMismatch);
    }
    let existing_target = history_head
        .members
        .iter()
        .find(|member| member.device_id == challenge.device_id);
    let key_reused = history_head.members.iter().any(|member| {
        member.signing_public_key == challenge.device_public_keys.signing
            || member.key_agreement_public_key == challenge.device_public_keys.key_agreement
    });
    if challenge.device_public_keys.key_agreement.as_bytes()
        == history_head.recovery_public_key.as_bytes()
    {
        return Err(AccountRecoveryProtocolError::PrepareBindingMismatch);
    }
    match input.kind {
        AccountRecoveryCommitKind::Resume => {
            let rekey_operation_id = input
                .rekey_operation_id
                .ok_or(AccountRecoveryProtocolError::InvalidPrepareInput)?;
            require_uuid_v4(&rekey_operation_id)?;
            if challenge.data_phase != AccountRecoveryDataPhase::RekeyPending
                || challenge.source_data_rekey_operation_id != Some(rekey_operation_id)
                || input.completion_session_id.is_some()
                || input.completion_session_token_digest.is_some()
                || existing_target.is_some()
                || key_reused
                || history_head.members.len() == MEMBERSHIP_MAX_MEMBERS
            {
                return Err(AccountRecoveryProtocolError::PrepareBindingMismatch);
            }
        }
        AccountRecoveryCommitKind::Replacement => {
            let completion_session_id = input
                .completion_session_id
                .ok_or(AccountRecoveryProtocolError::InvalidPrepareInput)?;
            require_uuid_v4(&completion_session_id)?;
            if challenge.data_phase != AccountRecoveryDataPhase::Ready
                || input.rekey_operation_id.is_some()
                || input.completion_session_token_digest.is_none()
            {
                return Err(AccountRecoveryProtocolError::PrepareBindingMismatch);
            }
            if let Some(existing) = existing_target {
                if history_head.operation_kind != 4
                    || history_head.issuer_device_id != challenge.device_id
                    || history_head.subject_device_id != challenge.device_id
                    || existing.key_version != challenge.device_key_version
                    || existing.auth_generation != input.target_auth_generation
                    || existing.signing_public_key != challenge.device_public_keys.signing
                    || existing.key_agreement_public_key
                        != challenge.device_public_keys.key_agreement
                {
                    return Err(AccountRecoveryProtocolError::PrepareBindingMismatch);
                }
            } else if key_reused {
                return Err(AccountRecoveryProtocolError::PrepareBindingMismatch);
            }
        }
    }
    Ok(())
}

fn self_envelope_binding(
    challenge: &VerifiedAccountRecoveryChallenge,
    key_epoch: u32,
) -> ArkEnvelopeBinding {
    ArkEnvelopeBinding {
        user_id: challenge.user_id,
        issuer_device_id: challenge.device_id,
        target_device_id: challenge.device_id,
        key_epoch,
        issuer_signing_public_key: challenge.device_public_keys.signing,
        issuer_key_agreement_public_key: challenge.device_public_keys.key_agreement,
        target_signing_public_key: challenge.device_public_keys.signing,
        target_key_agreement_public_key: challenge.device_public_keys.key_agreement,
    }
}

#[allow(clippy::too_many_arguments)]
fn build_membership_manifest(
    previous: &VerifiedRecoveryHistoryHead,
    security_generation: u32,
    key_epoch: u32,
    current_trust_public_key: crate::device_crypto::AccountTrustPublicKey,
    recovery_capsule_version: u32,
    recovery_capsule_digest: [u8; 32],
    operation_kind: u32,
    operation_id: [u8; 16],
    subject_device_id: DeviceId,
    members: &[RecoveryHistoryMember],
    transition: Option<(&AccountRootKey, u32)>,
    current: (&AccountRootKey, u32),
) -> Result<Vec<u8>, AccountRecoveryProtocolError> {
    if members.is_empty() || members.len() > MEMBERSHIP_MAX_MEMBERS {
        return Err(AccountRecoveryProtocolError::InvalidPrepareInput);
    }
    let payload_length = MEMBERSHIP_HEADER_LENGTH + members.len() * MEMBERSHIP_MEMBER_LENGTH;
    let mut manifest = vec![0_u8; payload_length + MEMBERSHIP_SIGNATURE_SECTION_LENGTH];
    manifest[..8].copy_from_slice(&MEMBERSHIP_MAGIC);
    manifest[8..12].copy_from_slice(&MEMBERSHIP_FORMAT_VERSION.to_be_bytes());
    manifest[12..28].copy_from_slice(previous.user_id.as_bytes());
    manifest[28..32].copy_from_slice(&security_generation.to_be_bytes());
    manifest[32..36].copy_from_slice(&key_epoch.to_be_bytes());
    manifest[36..68].copy_from_slice(&previous.digest);
    manifest[68..100].copy_from_slice(current_trust_public_key.as_bytes());
    manifest[100..104].copy_from_slice(&previous.recovery_public_key_version.to_be_bytes());
    manifest[104..136].copy_from_slice(previous.recovery_public_key.as_bytes());
    manifest[136..140].copy_from_slice(&recovery_capsule_version.to_be_bytes());
    manifest[140..172].copy_from_slice(&recovery_capsule_digest);
    manifest[172..176].copy_from_slice(&operation_kind.to_be_bytes());
    manifest[176..192].copy_from_slice(&operation_id);
    manifest[192..208].copy_from_slice(subject_device_id.as_bytes());
    manifest[208..224].copy_from_slice(subject_device_id.as_bytes());
    manifest[224..228].copy_from_slice(&(members.len() as u32).to_be_bytes());
    for (index, member) in members.iter().enumerate() {
        let offset = MEMBERSHIP_HEADER_LENGTH + index * MEMBERSHIP_MEMBER_LENGTH;
        manifest[offset..offset + 16].copy_from_slice(member.device_id.as_bytes());
        manifest[offset + 16..offset + 20].copy_from_slice(&member.key_version.to_be_bytes());
        manifest[offset + 20..offset + 24]
            .copy_from_slice(&member.auth_generation.to_be_bytes());
        manifest[offset + 24..offset + 56]
            .copy_from_slice(member.signing_public_key.as_bytes());
        manifest[offset + 56..offset + 88]
            .copy_from_slice(member.key_agreement_public_key.as_bytes());
    }
    if let Some((ark, epoch)) = transition {
        let signature = sign_account_trust_payload(
            ark,
            AccountTrustBinding {
                user_id: previous.user_id,
                key_epoch: epoch,
            },
            &manifest[..payload_length],
        )
        .map_err(|_| AccountRecoveryProtocolError::PrepareCryptoFailed)?;
        manifest[payload_length..payload_length + ACCOUNT_TRUST_SIGNATURE_LENGTH]
            .copy_from_slice(signature.as_bytes());
    }
    let signature = sign_account_trust_payload(
        current.0,
        AccountTrustBinding {
            user_id: previous.user_id,
            key_epoch: current.1,
        },
        &manifest[..payload_length],
    )
    .map_err(|_| AccountRecoveryProtocolError::PrepareCryptoFailed)?;
    manifest[payload_length + ACCOUNT_TRUST_SIGNATURE_LENGTH..]
        .copy_from_slice(signature.as_bytes());
    Ok(manifest)
}

#[allow(clippy::too_many_arguments)]
fn commit_request_digest(
    challenge: &VerifiedAccountRecoveryChallenge,
    input: AccountRecoveryPrepareInput,
    history_head: &VerifiedRecoveryHistoryHead,
    manifest: &[u8],
    manifest_digest: &[u8; 32],
    envelope_key_epoch: u32,
    envelope: &[u8; ARK_ENVELOPE_LENGTH],
    replacement: Option<(u32, &[u8; RECOVERY_CAPSULE_LENGTH])>,
) -> Result<[u8; 32], AccountRecoveryProtocolError> {
    let mut frame = Zeroizing::new(Vec::with_capacity(1024 + manifest.len()));
    frame.extend_from_slice(match input.kind {
        AccountRecoveryCommitKind::Resume => RESUME_REQUEST_DIGEST_DOMAIN,
        AccountRecoveryCommitKind::Replacement => REPLACEMENT_REQUEST_DIGEST_DOMAIN,
    });
    frame.extend_from_slice(&ACCOUNT_RECOVERY_PROTOCOL_VERSION.to_be_bytes());
    frame.extend_from_slice(&challenge.attempt_id);
    frame.extend_from_slice(challenge.user_id.as_bytes());
    frame.extend_from_slice(challenge.device_id.as_bytes());
    frame.extend_from_slice(&history_head.security_generation.to_be_bytes());
    frame.extend_from_slice(&history_head.key_epoch.to_be_bytes());
    frame.extend_from_slice(&history_head.digest);
    frame.extend_from_slice(&input.operation_id);
    extend_length_prefixed(&mut frame, manifest)?;
    frame.extend_from_slice(manifest_digest);
    frame.extend_from_slice(&1_u32.to_be_bytes());
    frame.extend_from_slice(&envelope_key_epoch.to_be_bytes());
    extend_length_prefixed(&mut frame, envelope)?;
    match input.kind {
        AccountRecoveryCommitKind::Resume => {
            frame.extend_from_slice(
                &input
                    .rekey_operation_id
                    .ok_or(AccountRecoveryProtocolError::InvalidPrepareInput)?,
            );
        }
        AccountRecoveryCommitKind::Replacement => {
            let (capsule_version, capsule) =
                replacement.ok_or(AccountRecoveryProtocolError::InvalidPrepareInput)?;
            frame.extend_from_slice(&capsule_version.to_be_bytes());
            extend_length_prefixed(&mut frame, capsule)?;
            frame.extend_from_slice(
                &input
                    .completion_session_id
                    .ok_or(AccountRecoveryProtocolError::InvalidPrepareInput)?,
            );
            frame.extend_from_slice(
                &input
                    .completion_session_token_digest
                    .ok_or(AccountRecoveryProtocolError::InvalidPrepareInput)?,
            );
        }
    }
    Ok(Sha256::digest(frame.as_slice()).into())
}

fn extend_length_prefixed(
    output: &mut Vec<u8>,
    value: &[u8],
) -> Result<(), AccountRecoveryProtocolError> {
    let length = u32::try_from(value.len())
        .map_err(|_| AccountRecoveryProtocolError::InvalidPrepareInput)?;
    output.extend_from_slice(&length.to_be_bytes());
    output.extend_from_slice(value);
    Ok(())
}

pub fn create_account_recovery_proof_material(
    challenge: &[u8],
    nonce: &[u8],
    recovery_token_digest: &[u8],
) -> Result<AccountRecoveryProofMaterial, AccountRecoveryProtocolError> {
    if challenge.len() != ACCOUNT_RECOVERY_CHALLENGE_LENGTH
        || nonce.len() != ACCOUNT_RECOVERY_NONCE_LENGTH
        || recovery_token_digest.len() != ACCOUNT_RECOVERY_TOKEN_DIGEST_LENGTH
    {
        return Err(AccountRecoveryProtocolError::InvalidProofInput);
    }
    let challenge_digest: [u8; 32] = Sha256::digest(challenge).into();
    let mut proof = AccountRecoveryProofMaterial {
        transcript: [0_u8; ACCOUNT_RECOVERY_PROOF_TRANSCRIPT_LENGTH],
        nonce_proof: [0_u8; ACCOUNT_RECOVERY_NONCE_PROOF_LENGTH],
        trust_signature_message: [0_u8; 32],
    };
    proof.transcript[..8].copy_from_slice(&PROOF_MAGIC);
    proof.transcript[8..12]
        .copy_from_slice(&ACCOUNT_RECOVERY_PROTOCOL_VERSION.to_be_bytes());
    proof.transcript[12..44].copy_from_slice(&challenge_digest);
    proof.transcript[44..76].copy_from_slice(nonce);
    proof.transcript[76..].copy_from_slice(recovery_token_digest);
    proof.nonce_proof = Sha256::digest(&proof.transcript).into();
    let mut trust_input = Zeroizing::new(Vec::with_capacity(
        TRUST_SIGNATURE_DOMAIN.len() + ACCOUNT_RECOVERY_PROOF_TRANSCRIPT_LENGTH,
    ));
    trust_input.extend_from_slice(TRUST_SIGNATURE_DOMAIN);
    trust_input.extend_from_slice(&proof.transcript);
    proof.trust_signature_message = Sha256::digest(trust_input.as_slice()).into();
    Ok(proof)
}

pub fn open_account_recovery_nonce(
    identity: &RecoveryIdentity,
    challenge: &VerifiedAccountRecoveryChallenge,
    sealed_nonce: &[u8],
) -> Result<Zeroizing<[u8; ACCOUNT_RECOVERY_NONCE_LENGTH]>, AccountRecoveryProtocolError> {
    if sealed_nonce.len() != ACCOUNT_RECOVERY_SEALED_NONCE_LENGTH {
        return Err(AccountRecoveryProtocolError::InvalidSealedNonceLength {
            actual: sealed_nonce.len(),
        });
    }
    require_sealed_nonce_header(sealed_nonce)?;
    let private_key = identity
        .hpke_private_key()
        .map_err(|_| AccountRecoveryProtocolError::InvalidSealedNonceKey)?;
    let encapsulated_key = <<HpkeKem as HpkeKemTrait>::EncappedKey as Deserializable>::from_bytes(
        &sealed_nonce[SEALED_NONCE_ENCAPSULATED_KEY_OFFSET..SEALED_NONCE_CIPHERTEXT_OFFSET],
    )
    .map_err(|_| AccountRecoveryProtocolError::InvalidSealedNonceKey)?;
    let mut info = Zeroizing::new(Vec::with_capacity(
        HPKE_INFO_DOMAIN.len() + ACCOUNT_RECOVERY_CHALLENGE_LENGTH,
    ));
    info.extend_from_slice(HPKE_INFO_DOMAIN);
    info.extend_from_slice(challenge.as_bytes());
    let mut aad = Zeroizing::new(Vec::with_capacity(
        HPKE_AAD_DOMAIN.len() + ACCOUNT_RECOVERY_CHALLENGE_LENGTH,
    ));
    aad.extend_from_slice(HPKE_AAD_DOMAIN);
    aad.extend_from_slice(challenge.as_bytes());
    let mut context = setup_receiver::<HpkeAead, HpkeKdf, HpkeKem>(
        &OpModeR::Base,
        &private_key,
        &encapsulated_key,
        info.as_slice(),
    )
    .map_err(|_| AccountRecoveryProtocolError::SealedNonceAuthenticationFailed)?;
    let mut nonce = Zeroizing::new(copy_array(
        &sealed_nonce[SEALED_NONCE_CIPHERTEXT_OFFSET..SEALED_NONCE_TAG_OFFSET],
    ));
    let tag = AeadTag::<HpkeAead>::from_bytes(&sealed_nonce[SEALED_NONCE_TAG_OFFSET..])
        .map_err(|_| AccountRecoveryProtocolError::SealedNonceAuthenticationFailed)?;
    context
        .open_inout_detached(InOutBuf::from(nonce.as_mut_slice()), aad.as_slice(), &tag)
        .map_err(|_| AccountRecoveryProtocolError::SealedNonceAuthenticationFailed)?;
    Ok(nonce)
}

pub fn seal_account_recovery_nonce<R>(
    rng: &mut R,
    recovery_public_key: RecoveryPublicKey,
    challenge: &[u8; ACCOUNT_RECOVERY_CHALLENGE_LENGTH],
    nonce: &[u8; ACCOUNT_RECOVERY_NONCE_LENGTH],
) -> Result<[u8; ACCOUNT_RECOVERY_SEALED_NONCE_LENGTH], AccountRecoveryProtocolError>
where
    R: CryptoRng + RngCore,
{
    let public_key = <<HpkeKem as HpkeKemTrait>::PublicKey as Deserializable>::from_bytes(
        recovery_public_key.as_bytes(),
    )
    .map_err(|_| AccountRecoveryProtocolError::InvalidSealedNonceKey)?;
    let mut info = Zeroizing::new(Vec::with_capacity(
        HPKE_INFO_DOMAIN.len() + ACCOUNT_RECOVERY_CHALLENGE_LENGTH,
    ));
    info.extend_from_slice(HPKE_INFO_DOMAIN);
    info.extend_from_slice(challenge);
    let mut aad = Zeroizing::new(Vec::with_capacity(
        HPKE_AAD_DOMAIN.len() + ACCOUNT_RECOVERY_CHALLENGE_LENGTH,
    ));
    aad.extend_from_slice(HPKE_AAD_DOMAIN);
    aad.extend_from_slice(challenge);
    let mut rng = HpkeRngAdapter::from_rng(rng)
        .map_err(|_| AccountRecoveryProtocolError::RandomnessUnavailable)?;
    let (encapsulated_key, mut context) =
        setup_sender_with_rng::<HpkeAead, HpkeKdf, HpkeKem>(
            &OpModeS::Base,
            &public_key,
            info.as_slice(),
            &mut rng,
        )
        .map_err(|_| AccountRecoveryProtocolError::SealedNonceCreationFailed)?;
    let mut ciphertext = Zeroizing::new(*nonce);
    let tag = context
        .seal_inout_detached(InOutBuf::from(ciphertext.as_mut_slice()), aad.as_slice())
        .map_err(|_| AccountRecoveryProtocolError::SealedNonceCreationFailed)?;
    let mut output = [0_u8; ACCOUNT_RECOVERY_SEALED_NONCE_LENGTH];
    output[..8].copy_from_slice(&SEALED_NONCE_MAGIC);
    output[8..12].copy_from_slice(&ACCOUNT_RECOVERY_PROTOCOL_VERSION.to_be_bytes());
    output[12..14].copy_from_slice(&HPKE_KEM_ID.to_be_bytes());
    output[14..16].copy_from_slice(&HPKE_KDF_ID.to_be_bytes());
    output[16..18].copy_from_slice(&HPKE_AEAD_ID.to_be_bytes());
    output[SEALED_NONCE_ENCAPSULATED_KEY_OFFSET..SEALED_NONCE_CIPHERTEXT_OFFSET]
        .copy_from_slice(encapsulated_key.to_bytes().as_slice());
    output[SEALED_NONCE_CIPHERTEXT_OFFSET..SEALED_NONCE_TAG_OFFSET]
        .copy_from_slice(ciphertext.as_slice());
    output[SEALED_NONCE_TAG_OFFSET..].copy_from_slice(tag.to_bytes().as_slice());
    Ok(output)
}

fn require_sealed_nonce_header(wire: &[u8]) -> Result<(), AccountRecoveryProtocolError> {
    if wire[..8] != SEALED_NONCE_MAGIC
        || read_u32(wire, 8) != ACCOUNT_RECOVERY_PROTOCOL_VERSION
        || read_u16(wire, 12) != HPKE_KEM_ID
        || read_u16(wire, 14) != HPKE_KDF_ID
        || read_u16(wire, 16) != HPKE_AEAD_ID
        || read_u16(wire, 18) != 0
    {
        return Err(AccountRecoveryProtocolError::InvalidSealedNonceHeader);
    }
    Ok(())
}

fn require_uuid_v4(bytes: &[u8; 16]) -> Result<(), AccountRecoveryProtocolError> {
    if bytes[6] & 0xf0 != 0x40 || bytes[8] & 0xc0 != 0x80 {
        return Err(AccountRecoveryProtocolError::InvalidChallengeBinding);
    }
    Ok(())
}

fn read_u16(bytes: &[u8], offset: usize) -> u16 {
    u16::from_be_bytes(copy_array(&bytes[offset..offset + 2]))
}

fn read_u32(bytes: &[u8], offset: usize) -> u32 {
    u32::from_be_bytes(copy_array(&bytes[offset..offset + 4]))
}

fn read_u64(bytes: &[u8], offset: usize) -> u64 {
    u64::from_be_bytes(copy_array(&bytes[offset..offset + 8]))
}

fn copy_array<const LENGTH: usize>(bytes: &[u8]) -> [u8; LENGTH] {
    let mut output = [0_u8; LENGTH];
    output.copy_from_slice(bytes);
    output
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        device_crypto::{
            AccountTrustSignature, DeviceIdentity, verify_account_trust_payload,
        },
        recovery_crypto::{RecoveryIdentity, VerifiedRecoveryHistoryHead},
    };

    struct TestRng(u8);

    impl RngCore for TestRng {
        fn next_u32(&mut self) -> u32 {
            u32::from_le_bytes([self.0; 4])
        }

        fn next_u64(&mut self) -> u64 {
            u64::from_le_bytes([self.0; 8])
        }

        fn fill_bytes(&mut self, destination: &mut [u8]) {
            destination.fill(self.0);
        }

        fn try_fill_bytes(&mut self, destination: &mut [u8]) -> Result<(), rand::Error> {
            self.fill_bytes(destination);
            Ok(())
        }
    }

    impl CryptoRng for TestRng {}

    fn decode_hex<const LENGTH: usize>(value: &str) -> [u8; LENGTH] {
        assert_eq!(value.len(), LENGTH * 2);
        let mut output = [0_u8; LENGTH];
        for (index, byte) in output.iter_mut().enumerate() {
            *byte = u8::from_str_radix(&value[index * 2..index * 2 + 2], 16)
                .expect("测试十六进制必须有效");
        }
        output
    }

    #[test]
    fn proof_transcript_and_nonce_proof_match_server_fixed_vector() {
        let challenge = server_vector_challenge();
        let nonce = [0x31; ACCOUNT_RECOVERY_NONCE_LENGTH];
        let token_digest = [0x61; ACCOUNT_RECOVERY_TOKEN_DIGEST_LENGTH];
        let mut proof = create_account_recovery_proof_material(
            &challenge,
            &nonce,
            &token_digest,
        )
        .expect("固定输入应生成 proof");

        assert_eq!(
            proof.transcript,
            decode_hex(
                "4b454c49564f525000000001258e73be6c11d50c0ed65123bd97cd05d1f764522ab4ffec4aedc3888cc4366931313131313131313131313131313131313131313131313131313131313131316161616161616161616161616161616161616161616161616161616161616161",
            ),
        );
        assert_eq!(
            proof.nonce_proof,
            decode_hex(
                "99f8454d1e5250d257767863db8b14e9c35767bbce767b1d57916eaea3d7c11c",
            ),
        );
        assert!(std::mem::needs_drop::<AccountRecoveryProofMaterial>());
        zeroize::Zeroize::zeroize(&mut proof);
        assert!(proof.transcript.iter().all(|byte| *byte == 0));
        assert!(proof.nonce_proof.iter().all(|byte| *byte == 0));
        assert!(
            proof
                .trust_signature_message
                .iter()
                .all(|byte| *byte == 0)
        );
    }

    #[test]
    fn challenge_parser_rejects_truncation_reserved_bytes_and_wrong_device() {
        let (frame, expected) = valid_challenge();
        VerifiedAccountRecoveryChallenge::parse_and_bind(&frame, expected)
            .expect("完整服务端向量应通过");

        assert!(VerifiedAccountRecoveryChallenge::parse_and_bind(
            &frame[..frame.len() - 1],
            expected,
        )
        .is_err());
        let mut reserved = frame;
        reserved[19] = 1;
        assert!(VerifiedAccountRecoveryChallenge::parse_and_bind(&reserved, expected).is_err());
        let mut wrong_device = expected;
        wrong_device.device_id = DeviceId::new(uuid(0x7a)).expect("另一设备应有效");
        assert!(VerifiedAccountRecoveryChallenge::parse_and_bind(&frame, wrong_device).is_err());
    }

    #[test]
    fn hpke_sealed_nonce_matches_server_fixed_vector_and_authenticates_challenge() {
        let frame = server_vector_challenge();
        let identity = RecoveryIdentity::from_private_bytes([0x21; 32])
            .expect("固定恢复私钥应有效");
        let public_key = identity.public_key().expect("固定恢复公钥应派生");
        let sealed = seal_account_recovery_nonce(
            &mut TestRng(0x41),
            public_key,
            &frame,
            &[0x31; 32],
        )
        .expect("固定 HPKE 向量应密封");
        assert_eq!(
            sealed,
            decode_hex(
                "4b454c49564f5253000000010020000100030000fd2c4dd1c8a6b88fe1fc59ce441398f5ea83a9296e210997ac63bed970b8602878b7fba667ceca4033e48cbd978fca1a274b9ef47beeb445c16c0a82e47b059ae2f41ef55660b731df2429aeaaa8f6f1",
            ),
        );
    }

    #[test]
    fn resume_and_replacement_prepare_bind_the_verified_head_and_mobile_identity() {
        let (device, challenge, head, current_ark) = prepare_context(AccountRecoveryDataPhase::RekeyPending);
        let resume = prepare_account_recovery_commit(
            &mut TestRng(0x61),
            &current_ark,
            &device,
            &challenge,
            &head,
            AccountRecoveryPrepareInput {
                kind: AccountRecoveryCommitKind::Resume,
                operation_id: uuid(0x55),
                target_auth_generation: 1,
                rekey_operation_id: Some(uuid(0x44)),
                completion_session_id: None,
                completion_session_token_digest: None,
            },
        )
        .expect("rekey-pending challenge 应准备恢复接续");
        assert_eq!(read_u32(&resume.manifest, 172), 4);
        assert_eq!(resume.next_key_epoch, head.key_epoch);
        assert!(resume.next_recovery_capsule.is_none());
        verify_manifest_signature(&resume.manifest, &current_ark, head.user_id, head.key_epoch, false);
        let opened = device
            .open_ark_envelope(
                resume.envelope.as_bytes(),
                self_envelope_binding(&challenge, head.key_epoch),
            )
            .expect("恢复接续 KAEK 应由目标移动身份打开");
        assert_eq!(opened.as_bytes(), current_ark.as_bytes());

        let (device, challenge, head, current_ark) = prepare_context(AccountRecoveryDataPhase::Ready);
        let replacement = prepare_account_recovery_commit(
            &mut TestRng(0x62),
            &current_ark,
            &device,
            &challenge,
            &head,
            AccountRecoveryPrepareInput {
                kind: AccountRecoveryCommitKind::Replacement,
                operation_id: uuid(0x56),
                target_auth_generation: 1,
                rekey_operation_id: None,
                completion_session_id: Some(uuid(0x57)),
                completion_session_token_digest: Some([0x58; 32]),
            },
        )
        .expect("ready challenge 应准备恢复替换");
        assert_eq!(read_u32(&replacement.manifest, 172), 5);
        assert_eq!(replacement.next_key_epoch, head.key_epoch + 1);
        assert!(replacement.next_recovery_capsule.is_some());
        verify_manifest_signature(
            &replacement.manifest,
            &current_ark,
            head.user_id,
            head.key_epoch,
            true,
        );
        let next_ark = replacement.next_ark.as_ref().expect("替换必须生成下一代 ARK");
        verify_current_manifest_signature(
            &replacement.manifest,
            next_ark,
            head.user_id,
            head.key_epoch + 1,
        );
        let opened = device
            .open_ark_envelope(
                replacement.envelope.as_bytes(),
                self_envelope_binding(&challenge, head.key_epoch + 1),
            )
            .expect("恢复替换 KAEK 应由目标移动身份打开");
        assert_eq!(opened.as_bytes(), next_ark.as_bytes());
    }

    #[test]
    fn prepare_rejects_wrong_phase_replay_and_cross_device_identity() {
        let (device, challenge, head, current_ark) = prepare_context(AccountRecoveryDataPhase::Ready);
        let resume_input = AccountRecoveryPrepareInput {
            kind: AccountRecoveryCommitKind::Resume,
            operation_id: uuid(0x55),
            target_auth_generation: 1,
            rekey_operation_id: Some(uuid(0x44)),
            completion_session_id: None,
            completion_session_token_digest: None,
        };
        assert!(prepare_account_recovery_commit(
            &mut TestRng(0x63),
            &current_ark,
            &device,
            &challenge,
            &head,
            resume_input,
        ).is_err());
        let other_device = DeviceIdentity::generate(&mut TestRng(0x64)).expect("另一设备应生成");
        let replacement_input = AccountRecoveryPrepareInput {
            kind: AccountRecoveryCommitKind::Replacement,
            operation_id: head.operation_id,
            target_auth_generation: 1,
            rekey_operation_id: None,
            completion_session_id: Some(uuid(0x57)),
            completion_session_token_digest: Some([0x58; 32]),
        };
        assert!(prepare_account_recovery_commit(
            &mut TestRng(0x65),
            &current_ark,
            &other_device,
            &challenge,
            &head,
            replacement_input,
        ).is_err());
    }

    #[test]
    fn replacement_after_resume_rejects_another_existing_subject() {
        let (device, challenge, mut head, current_ark) =
            prepare_context(AccountRecoveryDataPhase::Ready);
        head.operation_kind = 4;
        head.members.push(RecoveryHistoryMember {
            device_id: challenge.device_id,
            key_version: challenge.device_key_version,
            auth_generation: 1,
            signing_public_key: challenge.device_public_keys.signing,
            key_agreement_public_key: challenge.device_public_keys.key_agreement,
        });

        let error = prepare_account_recovery_commit(
            &mut TestRng(0x66),
            &current_ark,
            &device,
            &challenge,
            &head,
            AccountRecoveryPrepareInput {
                kind: AccountRecoveryCommitKind::Replacement,
                operation_id: uuid(0x56),
                target_auth_generation: 1,
                rekey_operation_id: None,
                completion_session_id: Some(uuid(0x57)),
                completion_session_token_digest: Some([0x58; 32]),
            },
        )
        .err();

        assert_eq!(
            error,
            Some(AccountRecoveryProtocolError::PrepareBindingMismatch)
        );
    }

    #[test]
    fn replacement_after_resume_accepts_the_same_subject() {
        let (device, challenge, mut head, current_ark) =
            prepare_context(AccountRecoveryDataPhase::Ready);
        head.operation_kind = 4;
        head.issuer_device_id = challenge.device_id;
        head.subject_device_id = challenge.device_id;
        head.members.push(RecoveryHistoryMember {
            device_id: challenge.device_id,
            key_version: challenge.device_key_version,
            auth_generation: 1,
            signing_public_key: challenge.device_public_keys.signing,
            key_agreement_public_key: challenge.device_public_keys.key_agreement,
        });

        let prepared = prepare_account_recovery_commit(
            &mut TestRng(0x67),
            &current_ark,
            &device,
            &challenge,
            &head,
            AccountRecoveryPrepareInput {
                kind: AccountRecoveryCommitKind::Replacement,
                operation_id: uuid(0x56),
                target_auth_generation: 1,
                rekey_operation_id: None,
                completion_session_id: Some(uuid(0x57)),
                completion_session_token_digest: Some([0x58; 32]),
            },
        );

        assert!(prepared.is_ok());
    }

    fn prepare_context(
        phase: AccountRecoveryDataPhase,
    ) -> (
        DeviceIdentity,
        VerifiedAccountRecoveryChallenge,
        VerifiedRecoveryHistoryHead,
        AccountRootKey,
    ) {
        let device = DeviceIdentity::generate(&mut TestRng(0x51)).expect("设备身份应生成");
        let device_public_keys = device.public_keys();
        let recovery = RecoveryIdentity::generate(&mut TestRng(0x52)).expect("恢复身份应生成");
        let recovery_public_key = recovery.public_key().expect("恢复公钥应派生");
        let attempt_id = uuid(0x11);
        let user_id = UserId::new(uuid(0x22)).expect("账户应有效");
        let device_id = DeviceId::new(uuid(0x33)).expect("设备应有效");
        let mut frame = encode_challenge(
            attempt_id,
            user_id,
            device_id,
            device_public_keys,
            recovery_public_key,
        );
        match phase {
            AccountRecoveryDataPhase::Ready => {
                frame[CHALLENGE_DATA_PHASE_OFFSET] = 0;
                frame[CHALLENGE_SOURCE_REKEY_OPERATION_OFFSET..CHALLENGE_EXPIRES_AT_OFFSET]
                    .fill(0);
            }
            AccountRecoveryDataPhase::RekeyPending => {}
        }
        let expectation = AccountRecoveryChallengeExpectation {
            attempt_id,
            user_id,
            device_id,
            device_key_version: 1,
            device_public_keys,
            security_generation: 7,
            key_epoch: 9,
            membership_manifest_digest: [0x13; 32],
            recovery_public_key_version: 2,
            recovery_public_key,
            recovery_capsule_version: 3,
            recovery_capsule_digest: [0x15; 32],
            expires_at_ms: 1_785_369_000_000,
            request_digest: [0x16; 32],
        };
        let challenge = VerifiedAccountRecoveryChallenge::parse_and_bind(&frame, expectation)
            .expect("测试 challenge 应有效");
        let current_ark = AccountRootKey::from_bytes([0x71; 32]);
        let current_trust_public_key = derive_account_trust_public_key(
            &current_ark,
            AccountTrustBinding { user_id, key_epoch: 9 },
        )
        .expect("当前信任公钥应派生");
        let existing_identity = DeviceIdentity::generate(&mut TestRng(0x72))
            .expect("既有设备身份应生成");
        let existing_public = existing_identity.public_keys();
        let existing_device_id = DeviceId::new(uuid(0x73)).expect("既有设备应有效");
        let head = VerifiedRecoveryHistoryHead {
            user_id,
            security_generation: 7,
            key_epoch: 9,
            digest: [0x13; 32],
            current_trust_public_key,
            recovery_public_key_version: 2,
            recovery_public_key,
            recovery_capsule_version: 3,
            recovery_capsule_digest: [0x15; 32],
            operation_kind: 3,
            operation_id: uuid(0x74),
            issuer_device_id: existing_device_id,
            subject_device_id: existing_device_id,
            members: vec![RecoveryHistoryMember {
                device_id: existing_device_id,
                key_version: 1,
                auth_generation: 1,
                signing_public_key: existing_public.signing,
                key_agreement_public_key: existing_public.key_agreement,
            }],
            operation_ids: vec![uuid(0x74)],
            manifest: vec![0_u8; 444],
        };
        (device, challenge, head, current_ark)
    }

    fn verify_manifest_signature(
        manifest: &[u8],
        ark: &AccountRootKey,
        user_id: UserId,
        key_epoch: u32,
        transition_required: bool,
    ) {
        let payload_length = manifest.len() - MEMBERSHIP_SIGNATURE_SECTION_LENGTH;
        let transition = AccountTrustSignature::from_bytes(
            &manifest[payload_length..payload_length + ACCOUNT_TRUST_SIGNATURE_LENGTH],
        )
        .expect("过渡签名应编码有效");
        if transition_required {
            let public_key = derive_account_trust_public_key(
                ark,
                AccountTrustBinding { user_id, key_epoch },
            )
            .expect("过渡公钥应派生");
            verify_account_trust_payload(
                &public_key,
                AccountTrustBinding { user_id, key_epoch },
                &manifest[..payload_length],
                &transition,
            )
            .expect("过渡签名应验证");
        } else {
            assert!(transition.as_bytes().iter().all(|byte| *byte == 0));
            verify_current_manifest_signature(manifest, ark, user_id, key_epoch);
        }
    }

    fn verify_current_manifest_signature(
        manifest: &[u8],
        ark: &AccountRootKey,
        user_id: UserId,
        key_epoch: u32,
    ) {
        let payload_length = manifest.len() - MEMBERSHIP_SIGNATURE_SECTION_LENGTH;
        let current = AccountTrustSignature::from_bytes(
            &manifest[payload_length + ACCOUNT_TRUST_SIGNATURE_LENGTH..],
        )
        .expect("当前签名应编码有效");
        let public_key = derive_account_trust_public_key(
            ark,
            AccountTrustBinding { user_id, key_epoch },
        )
        .expect("当前公钥应派生");
        verify_account_trust_payload(
            &public_key,
            AccountTrustBinding { user_id, key_epoch },
            &manifest[..payload_length],
            &current,
        )
        .expect("当前签名应验证");
    }

    fn valid_challenge() -> (
        [u8; ACCOUNT_RECOVERY_CHALLENGE_LENGTH],
        AccountRecoveryChallengeExpectation,
    ) {
        let device = DeviceIdentity::generate(&mut TestRng(0x51)).expect("设备身份应生成");
        let device_public_keys = device.public_keys();
        let recovery =
            RecoveryIdentity::generate(&mut TestRng(0x52)).expect("恢复身份应生成");
        let recovery_public_key = recovery.public_key().expect("恢复公钥应派生");
        let attempt_id = uuid(0x11);
        let user_id = UserId::new(uuid(0x22)).expect("账户应有效");
        let device_id = DeviceId::new(uuid(0x33)).expect("设备应有效");
        let request_digest = [0x16; 32];
        let mut frame = encode_challenge(
            attempt_id,
            user_id,
            device_id,
            device_public_keys,
            recovery_public_key,
        );
        frame[CHALLENGE_REQUEST_DIGEST_OFFSET..].copy_from_slice(&request_digest);
        let expected = AccountRecoveryChallengeExpectation {
            attempt_id,
            user_id,
            device_id,
            device_key_version: 1,
            device_public_keys,
            security_generation: 7,
            key_epoch: 9,
            membership_manifest_digest: [0x13; 32],
            recovery_public_key_version: 2,
            recovery_public_key,
            recovery_capsule_version: 3,
            recovery_capsule_digest: [0x15; 32],
            expires_at_ms: 1_785_369_000_000,
            request_digest,
        };
        (frame, expected)
    }

    fn server_vector_challenge() -> [u8; ACCOUNT_RECOVERY_CHALLENGE_LENGTH] {
        let recovery = RecoveryIdentity::from_private_bytes([0x21; 32])
            .expect("固定恢复私钥应有效");
        let recovery_public_key = recovery.public_key().expect("固定恢复公钥应派生");
        let mut frame = [0_u8; ACCOUNT_RECOVERY_CHALLENGE_LENGTH];
        frame[..8].copy_from_slice(&CHALLENGE_MAGIC);
        frame[8..12].copy_from_slice(&ACCOUNT_RECOVERY_PROTOCOL_VERSION.to_be_bytes());
        frame[12..14].copy_from_slice(&HPKE_KEM_ID.to_be_bytes());
        frame[14..16].copy_from_slice(&HPKE_KDF_ID.to_be_bytes());
        frame[16..18].copy_from_slice(&HPKE_AEAD_ID.to_be_bytes());
        frame[CHALLENGE_ATTEMPT_OFFSET..CHALLENGE_USER_OFFSET].copy_from_slice(&uuid(0x11));
        frame[CHALLENGE_USER_OFFSET..CHALLENGE_DEVICE_OFFSET].copy_from_slice(&uuid(0x22));
        frame[CHALLENGE_DEVICE_OFFSET..CHALLENGE_DEVICE_KEY_VERSION_OFFSET]
            .copy_from_slice(&uuid(0x33));
        frame[CHALLENGE_DEVICE_KEY_VERSION_OFFSET..CHALLENGE_DEVICE_SIGNING_KEY_OFFSET]
            .copy_from_slice(&1_u32.to_be_bytes());
        frame[CHALLENGE_DEVICE_SIGNING_KEY_OFFSET..CHALLENGE_DEVICE_AGREEMENT_KEY_OFFSET]
            .fill(0x11);
        frame[CHALLENGE_DEVICE_AGREEMENT_KEY_OFFSET..CHALLENGE_SECURITY_GENERATION_OFFSET]
            .fill(0x12);
        frame[CHALLENGE_SECURITY_GENERATION_OFFSET..CHALLENGE_KEY_EPOCH_OFFSET]
            .copy_from_slice(&7_u32.to_be_bytes());
        frame[CHALLENGE_KEY_EPOCH_OFFSET..CHALLENGE_MEMBERSHIP_DIGEST_OFFSET]
            .copy_from_slice(&9_u32.to_be_bytes());
        frame[CHALLENGE_MEMBERSHIP_DIGEST_OFFSET..CHALLENGE_RECOVERY_KEY_VERSION_OFFSET]
            .fill(0x13);
        frame[CHALLENGE_RECOVERY_KEY_VERSION_OFFSET..CHALLENGE_RECOVERY_KEY_OFFSET]
            .copy_from_slice(&2_u32.to_be_bytes());
        frame[CHALLENGE_RECOVERY_KEY_OFFSET..CHALLENGE_CAPSULE_VERSION_OFFSET]
            .copy_from_slice(recovery_public_key.as_bytes());
        frame[CHALLENGE_CAPSULE_VERSION_OFFSET..CHALLENGE_CAPSULE_DIGEST_OFFSET]
            .copy_from_slice(&3_u32.to_be_bytes());
        frame[CHALLENGE_CAPSULE_DIGEST_OFFSET..CHALLENGE_DATA_PHASE_OFFSET].fill(0x15);
        frame[CHALLENGE_DATA_PHASE_OFFSET] = 1;
        frame[CHALLENGE_SOURCE_DATA_GENERATION_OFFSET..CHALLENGE_SOURCE_DATA_KEY_EPOCH_OFFSET]
            .copy_from_slice(&5_u32.to_be_bytes());
        frame[CHALLENGE_SOURCE_DATA_KEY_EPOCH_OFFSET..CHALLENGE_SOURCE_REKEY_OPERATION_OFFSET]
            .copy_from_slice(&8_u32.to_be_bytes());
        frame[CHALLENGE_SOURCE_REKEY_OPERATION_OFFSET..CHALLENGE_EXPIRES_AT_OFFSET]
            .copy_from_slice(&uuid(0x44));
        frame[CHALLENGE_EXPIRES_AT_OFFSET..CHALLENGE_REQUEST_DIGEST_OFFSET]
            .copy_from_slice(&1_785_369_000_000_u64.to_be_bytes());
        frame[CHALLENGE_REQUEST_DIGEST_OFFSET..].fill(0x16);
        frame
    }

    fn encode_challenge(
        attempt_id: [u8; 16],
        user_id: UserId,
        device_id: DeviceId,
        device_public_keys: DevicePublicKeys,
        recovery_public_key: RecoveryPublicKey,
    ) -> [u8; ACCOUNT_RECOVERY_CHALLENGE_LENGTH] {
        let mut frame = server_vector_challenge();
        frame[CHALLENGE_ATTEMPT_OFFSET..CHALLENGE_USER_OFFSET].copy_from_slice(&attempt_id);
        frame[CHALLENGE_USER_OFFSET..CHALLENGE_DEVICE_OFFSET]
            .copy_from_slice(user_id.as_bytes());
        frame[CHALLENGE_DEVICE_OFFSET..CHALLENGE_DEVICE_KEY_VERSION_OFFSET]
            .copy_from_slice(device_id.as_bytes());
        frame[CHALLENGE_DEVICE_SIGNING_KEY_OFFSET..CHALLENGE_DEVICE_AGREEMENT_KEY_OFFSET]
            .copy_from_slice(device_public_keys.signing.as_bytes());
        frame[CHALLENGE_DEVICE_AGREEMENT_KEY_OFFSET..CHALLENGE_SECURITY_GENERATION_OFFSET]
            .copy_from_slice(device_public_keys.key_agreement.as_bytes());
        frame[CHALLENGE_RECOVERY_KEY_OFFSET..CHALLENGE_CAPSULE_VERSION_OFFSET]
            .copy_from_slice(recovery_public_key.as_bytes());
        frame
    }

    fn uuid(seed: u8) -> [u8; 16] {
        let mut value = [seed; 16];
        value[6] = (value[6] & 0x0f) | 0x40;
        value[8] = (value[8] & 0x0f) | 0x80;
        value
    }
}
