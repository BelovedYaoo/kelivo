use std::{
    collections::HashMap,
    sync::{Arc, Mutex, OnceLock},
    time::{Duration, Instant},
};

use hkdf::Hkdf;
use hmac::{Hmac, KeyInit as HmacKeyInit, Mac};
use kelivo_secure_core_protocol::{self as protocol, device_crypto as crypto};
use rand::RngCore;
use sha2::{Digest, Sha256};
use zeroize::{Zeroize, Zeroizing};

use crate::{
    ACCOUNT_ROOT_KEY_HANDLE_TAG, DEVICE_IDENTITY_HANDLE_TAG, INVALID_KEY_HANDLE, KelivoStatus,
    LocalKey, PENDING_PAIRING_HANDLE_TAG, handle_has_tag, issue_typed_handle, key_for_handle,
    master_key, read_input, write_bytes, write_output,
};

pub(super) const DEVICE_PUBLIC_KEYS_LENGTH: usize = crypto::DEVICE_PUBLIC_KEY_LENGTH * 2;
pub(super) const ACCOUNT_TRUST_PUBLIC_KEY_LENGTH: usize = crypto::ACCOUNT_TRUST_PUBLIC_KEY_LENGTH;
pub(super) const ACCOUNT_TRUST_SIGNATURE_LENGTH: usize = crypto::ACCOUNT_TRUST_SIGNATURE_LENGTH;
pub(super) const ACCOUNT_TRUST_PAYLOAD_MAX_LENGTH: usize = crypto::ACCOUNT_TRUST_PAYLOAD_MAX_LENGTH;
pub(super) const REGISTRATION_FINISH_BUNDLE_LENGTH: usize =
    crypto::ARK_ENVELOPE_LENGTH + crypto::DEVICE_PROOF_SIGNATURE_LENGTH;
pub(super) const PAIRING_APPROVAL_BUNDLE_LENGTH: usize = crypto::ARK_ENVELOPE_LENGTH
    + crypto::DEVICE_PROOF_SIGNATURE_LENGTH
    + crypto::PAIRING_AUTHENTICATOR_LENGTH;
pub(super) const PENDING_PAIRING_MATERIAL_LENGTH: usize =
    UUID_LENGTH + PAIRING_SECRET_LENGTH + crypto::SHA256_DIGEST_LENGTH;
pub(super) const DEVICE_STATE_BLOB_LENGTH: usize = crypto::DEVICE_STATE_BLOB_LENGTH;
pub(super) const DEVICE_STATE_BINDING_STRUCT_SIZE: u32 = 48;
pub(super) const RECORD_ENTITY_KEY_MAX_LENGTH: usize = 2048;

const UUID_LENGTH: usize = 16;
pub(super) const DERIVED_RECORD_ID_LENGTH: usize = UUID_LENGTH;
pub(super) const DEVICE_STATE_BINDING_FLAG_ACCOUNT: u32 = 1;
const PAIRING_SECRET_LENGTH: usize = crypto::PAIRING_SECRET_LENGTH;
const PAIRING_PROTOCOL_VERSION: u32 = 1;
const PAIRING_LIFETIME_MILLISECONDS: u64 = 5 * 60 * 1000;
const PAIRING_LIFETIME: Duration = Duration::from_secs(5 * 60);
const STATE_KEY_INFO: &[u8] = b"kelivo.device-state.key.v1\0";
const RECORD_ID_KEY_INFO: &[u8] = b"kelivo.sync.record-id.key.v1\0";
const RECORD_ID_PRF_DOMAIN: &[u8] = b"kelivo.sync.record-id.v1\0";
const MAX_ACTIVE_DEVICE_IDENTITIES: usize = 64;
const MAX_ACTIVE_ACCOUNT_ROOT_KEYS: usize = 64;
const MAX_ACTIVE_PENDING_PAIRINGS: usize = 64;

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct KelivoDeviceStateBinding {
    pub struct_size: u32,
    pub flags: u32,
    pub device_id: [u8; UUID_LENGTH],
    pub key_version: u32,
    pub user_id: [u8; UUID_LENGTH],
    pub key_epoch: u32,
}

const _: () = assert!(
    core::mem::size_of::<KelivoDeviceStateBinding>() == DEVICE_STATE_BINDING_STRUCT_SIZE as usize
);

impl KelivoDeviceStateBinding {
    const fn empty() -> Self {
        Self {
            struct_size: 0,
            flags: 0,
            device_id: [0; UUID_LENGTH],
            key_version: 0,
            user_id: [0; UUID_LENGTH],
            key_epoch: 0,
        }
    }

    fn authenticated(binding: crypto::DeviceStateBinding) -> Self {
        let (flags, user_id, key_epoch) = match binding.account {
            Some(account) => (
                DEVICE_STATE_BINDING_FLAG_ACCOUNT,
                *account.user_id.as_bytes(),
                account.key_epoch,
            ),
            None => (0, [0; UUID_LENGTH], 0),
        };
        Self {
            struct_size: DEVICE_STATE_BINDING_STRUCT_SIZE,
            flags,
            device_id: *binding.device_id.as_bytes(),
            key_version: binding.key_version,
            user_id,
            key_epoch,
        }
    }
}

struct SecretRegistry<T> {
    active: HashMap<u64, Arc<T>>,
    next_sequence: u64,
}

impl<T> Default for SecretRegistry<T> {
    fn default() -> Self {
        Self {
            active: HashMap::new(),
            next_sequence: 1,
        }
    }
}

fn identity_registry() -> &'static Mutex<SecretRegistry<crypto::DeviceIdentity>> {
    static REGISTRY: OnceLock<Mutex<SecretRegistry<crypto::DeviceIdentity>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(SecretRegistry::default()))
}

struct BoundAccountRootKeyring {
    user_id: crypto::UserId,
    keyring: Mutex<crypto::AccountRootKeyring>,
}

fn ark_registry() -> &'static Mutex<SecretRegistry<BoundAccountRootKeyring>> {
    static REGISTRY: OnceLock<Mutex<SecretRegistry<BoundAccountRootKeyring>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(SecretRegistry::default()))
}

#[derive(Clone, Copy)]
struct BoundPairingTranscript {
    user_id: crypto::UserId,
    expires_at_ms: u64,
    challenge: crypto::DeviceProofChallenge,
}

struct PendingPairing {
    pairing_id: crypto::DeviceProofAttemptId,
    pairing_secret: Zeroizing<[u8; PAIRING_SECRET_LENGTH]>,
    target_device_id: crypto::DeviceId,
    target_key_version: u32,
    target_public_keys: crypto::DevicePublicKeys,
    deadline: Instant,
    bound: Option<BoundPairingTranscript>,
}

struct PendingPairingRegistry {
    active: HashMap<u64, PendingPairing>,
    next_sequence: u64,
}

impl Default for PendingPairingRegistry {
    fn default() -> Self {
        Self {
            active: HashMap::new(),
            next_sequence: 1,
        }
    }
}

fn pending_pairing_registry() -> &'static Mutex<PendingPairingRegistry> {
    static REGISTRY: OnceLock<Mutex<PendingPairingRegistry>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(PendingPairingRegistry::default()))
}

fn register_pending_pairing(pending: PendingPairing) -> Result<u64, KelivoStatus> {
    let mut registry = pending_pairing_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    if registry.active.len() >= MAX_ACTIVE_PENDING_PAIRINGS {
        return Err(KelivoStatus::TooManyActiveHandles);
    }
    let handle = issue_typed_handle(PENDING_PAIRING_HANDLE_TAG, &mut registry.next_sequence)?;
    let replaced = registry.active.insert(handle, pending);
    debug_assert!(replaced.is_none());
    Ok(handle)
}

fn close_pending_pairing(handle: u64) -> Result<(), KelivoStatus> {
    if !handle_has_tag(handle, PENDING_PAIRING_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidPendingPairingHandle);
    }
    let pending = pending_pairing_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .remove(&handle)
        .ok_or(KelivoStatus::InvalidPendingPairingHandle)?;
    drop(pending);
    Ok(())
}

#[derive(Clone, Copy)]
struct PairingBindInput {
    protocol_version: u32,
    pairing_id: crypto::DeviceProofAttemptId,
    user_id: crypto::UserId,
    target_device_id: crypto::DeviceId,
    target_key_version: u32,
    target_public_keys: crypto::DevicePublicKeys,
    expires_at_ms: u64,
    challenge: crypto::DeviceProofChallenge,
}

fn bind_pending_pairing_at(
    handle: u64,
    input: PairingBindInput,
    now_ms: u64,
    now: Instant,
) -> Result<(), KelivoStatus> {
    if !handle_has_tag(handle, PENDING_PAIRING_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidPendingPairingHandle);
    }
    if input.protocol_version != PAIRING_PROTOCOL_VERSION {
        return Err(KelivoStatus::DeviceMessageInvalid);
    }
    if input.expires_at_ms <= now_ms {
        return Err(KelivoStatus::PairingExpired);
    }
    if input.expires_at_ms - now_ms > PAIRING_LIFETIME_MILLISECONDS {
        return Err(KelivoStatus::DeviceMessageInvalid);
    }

    let mut registry = pending_pairing_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    let is_expired = registry
        .active
        .get(&handle)
        .ok_or(KelivoStatus::InvalidPendingPairingHandle)?
        .deadline
        < now;
    if is_expired {
        let expired = registry
            .active
            .remove(&handle)
            .expect("已在同一互斥区确认 pending 句柄存在");
        drop(expired);
        return Err(KelivoStatus::PairingExpired);
    }

    let pending = registry
        .active
        .get_mut(&handle)
        .expect("已在同一互斥区确认 pending 句柄存在");
    if pending.bound.is_some() {
        return Err(KelivoStatus::PendingPairingStateInvalid);
    }
    if pending.pairing_id != input.pairing_id
        || pending.target_device_id != input.target_device_id
        || pending.target_key_version != input.target_key_version
        || pending.target_public_keys != input.target_public_keys
    {
        return Err(KelivoStatus::DeviceAuthenticationFailed);
    }
    pending.bound = Some(BoundPairingTranscript {
        user_id: input.user_id,
        expires_at_ms: input.expires_at_ms,
        challenge: input.challenge,
    });
    Ok(())
}

struct PendingPairingPermit {
    handle: u64,
    pending: Option<PendingPairing>,
    restore_on_drop: bool,
}

impl PendingPairingPermit {
    fn pending(&self) -> &PendingPairing {
        self.pending.as_ref().expect("认领许可在提交前必须持有值")
    }

    fn commit(mut self) {
        self.restore_on_drop = false;
        drop(self.pending.take());
    }
}

impl Drop for PendingPairingPermit {
    fn drop(&mut self) {
        if !self.restore_on_drop {
            return;
        }
        let Some(pending) = self.pending.take() else {
            return;
        };
        let Ok(mut registry) = pending_pairing_registry().lock() else {
            return;
        };
        let replaced = registry.active.insert(self.handle, pending);
        debug_assert!(replaced.is_none());
    }
}

fn claim_pending_pairing_at(
    handle: u64,
    now_ms: u64,
    now: Instant,
) -> Result<PendingPairingPermit, KelivoStatus> {
    if !handle_has_tag(handle, PENDING_PAIRING_HANDLE_TAG) {
        return Err(KelivoStatus::InvalidPendingPairingHandle);
    }
    let pending = pending_pairing_registry()
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .remove(&handle)
        .ok_or(KelivoStatus::InvalidPendingPairingHandle)?;
    let permit = PendingPairingPermit {
        handle,
        pending: Some(pending),
        restore_on_drop: true,
    };
    let Some(bound) = permit.pending().bound else {
        return Err(KelivoStatus::PendingPairingStateInvalid);
    };
    if now >= permit.pending().deadline || now_ms >= bound.expires_at_ms {
        permit.commit();
        return Err(KelivoStatus::PairingExpired);
    }
    Ok(permit)
}

fn register_secret<T>(
    registry: &Mutex<SecretRegistry<T>>,
    value: T,
    tag: u64,
    limit: usize,
) -> Result<u64, KelivoStatus> {
    let mut registry = registry.lock().map_err(|_| KelivoStatus::InternalState)?;
    if registry.active.len() >= limit {
        return Err(KelivoStatus::TooManyActiveHandles);
    }
    let handle = issue_typed_handle(tag, &mut registry.next_sequence)?;
    let replaced = registry.active.insert(handle, Arc::new(value));
    debug_assert!(replaced.is_none());
    Ok(handle)
}

fn secret_for_handle<T>(
    registry: &Mutex<SecretRegistry<T>>,
    handle: u64,
    tag: u64,
    invalid_status: KelivoStatus,
) -> Result<Arc<T>, KelivoStatus> {
    if !handle_has_tag(handle, tag) {
        return Err(invalid_status);
    }
    registry
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .get(&handle)
        .cloned()
        .ok_or(invalid_status)
}

fn close_secret<T>(
    registry: &Mutex<SecretRegistry<T>>,
    handle: u64,
    tag: u64,
    invalid_status: KelivoStatus,
) -> Result<(), KelivoStatus> {
    if !handle_has_tag(handle, tag) {
        return Err(invalid_status);
    }
    let removed = registry
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .active
        .remove(&handle)
        .ok_or(invalid_status)?;
    drop(removed);
    Ok(())
}

fn register_identity(identity: crypto::DeviceIdentity) -> Result<u64, KelivoStatus> {
    register_secret(
        identity_registry(),
        identity,
        DEVICE_IDENTITY_HANDLE_TAG,
        MAX_ACTIVE_DEVICE_IDENTITIES,
    )
}

fn identity_for_handle(handle: u64) -> Result<Arc<crypto::DeviceIdentity>, KelivoStatus> {
    secret_for_handle(
        identity_registry(),
        handle,
        DEVICE_IDENTITY_HANDLE_TAG,
        KelivoStatus::InvalidDeviceIdentityHandle,
    )
}

fn close_identity(handle: u64) -> Result<(), KelivoStatus> {
    close_secret(
        identity_registry(),
        handle,
        DEVICE_IDENTITY_HANDLE_TAG,
        KelivoStatus::InvalidDeviceIdentityHandle,
    )
}

pub(super) fn register_ark(
    user_id: crypto::UserId,
    epoch: u32,
    ark: crypto::AccountRootKey,
) -> Result<u64, KelivoStatus> {
    let keyring = crypto::AccountRootKeyring::new(epoch, ark).map_err(device_error_status)?;
    register_keyring(user_id, keyring)
}

pub(super) fn register_recovered_ark_keyring(
    user_id: crypto::UserId,
    source: Option<(u32, crypto::AccountRootKey)>,
    current_epoch: u32,
    current: crypto::AccountRootKey,
) -> Result<u64, KelivoStatus> {
    let keyring = match source {
        Some((source_epoch, source)) => {
            if source_epoch.checked_add(1) != Some(current_epoch) {
                return Err(KelivoStatus::RecoveryHistoryInvalid);
            }
            let mut keyring = crypto::AccountRootKeyring::new(source_epoch, source)
                .map_err(device_error_status)?;
            keyring
                .add_current(current_epoch, current)
                .map_err(device_error_status)?;
            keyring
        }
        None => {
            crypto::AccountRootKeyring::new(current_epoch, current).map_err(device_error_status)?
        }
    };
    register_keyring(user_id, keyring)
}

fn register_keyring(
    user_id: crypto::UserId,
    keyring: crypto::AccountRootKeyring,
) -> Result<u64, KelivoStatus> {
    register_secret(
        ark_registry(),
        BoundAccountRootKeyring {
            user_id,
            keyring: Mutex::new(keyring),
        },
        ACCOUNT_ROOT_KEY_HANDLE_TAG,
        MAX_ACTIVE_ACCOUNT_ROOT_KEYS,
    )
}

fn bound_keyring_for_handle(handle: u64) -> Result<Arc<BoundAccountRootKeyring>, KelivoStatus> {
    secret_for_handle(
        ark_registry(),
        handle,
        ACCOUNT_ROOT_KEY_HANDLE_TAG,
        KelivoStatus::InvalidAccountRootKeyHandle,
    )
}

fn require_ark_account(
    bound: &BoundAccountRootKeyring,
    expected_user_id: crypto::UserId,
) -> Result<(), KelivoStatus> {
    if bound.user_id != expected_user_id {
        return Err(KelivoStatus::DeviceAuthenticationFailed);
    }
    Ok(())
}

pub(super) fn ark_for_handle(
    handle: u64,
    epoch: u32,
) -> Result<crypto::AccountRootKey, KelivoStatus> {
    let bound = bound_keyring_for_handle(handle)?;
    with_ark_for_bound_keyring(&bound, epoch, |key| {
        Ok(crypto::AccountRootKey::from_bytes(*key.as_bytes()))
    })
}

pub(super) fn ark_for_account_handle(
    handle: u64,
    expected_user_id: crypto::UserId,
    epoch: u32,
) -> Result<crypto::AccountRootKey, KelivoStatus> {
    with_ark_for_account_handle(handle, expected_user_id, epoch, |key| {
        Ok(crypto::AccountRootKey::from_bytes(*key.as_bytes()))
    })
}

fn with_ark_for_account_handle<T>(
    handle: u64,
    expected_user_id: crypto::UserId,
    epoch: u32,
    operation: impl FnOnce(&crypto::AccountRootKey) -> Result<T, KelivoStatus>,
) -> Result<T, KelivoStatus> {
    let bound = bound_keyring_for_handle(handle)?;
    require_ark_account(&bound, expected_user_id)?;
    with_ark_for_bound_keyring(&bound, epoch, operation)
}

fn with_ark_for_bound_keyring<T>(
    bound: &BoundAccountRootKeyring,
    epoch: u32,
    operation: impl FnOnce(&crypto::AccountRootKey) -> Result<T, KelivoStatus>,
) -> Result<T, KelivoStatus> {
    let keyring = bound
        .keyring
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    let key = keyring
        .key_for_epoch(epoch)
        .map_err(|_| KelivoStatus::InvalidArgument)?;
    operation(key)
}

fn keyring_snapshot_for_handle(
    handle: u64,
    expected_user_id: crypto::UserId,
    expected_current_epoch: u32,
) -> Result<crypto::AccountRootKeyring, KelivoStatus> {
    let bound = bound_keyring_for_handle(handle)?;
    require_ark_account(&bound, expected_user_id)?;
    let keyring = bound
        .keyring
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?;
    if keyring.current_epoch() != expected_current_epoch {
        return Err(KelivoStatus::DeviceStateInvalid);
    }
    let mut entries = keyring.entries();
    let (first_epoch, first_key) = entries.next().ok_or(KelivoStatus::InternalState)?;
    let mut snapshot = crypto::AccountRootKeyring::new(
        first_epoch,
        crypto::AccountRootKey::from_bytes(*first_key.as_bytes()),
    )
    .map_err(device_error_status)?;
    for (epoch, key) in entries {
        snapshot
            .add_current(epoch, crypto::AccountRootKey::from_bytes(*key.as_bytes()))
            .map_err(device_error_status)?;
    }
    Ok(snapshot)
}

fn merge_ark_epoch(target_handle: u64, source_handle: u64) -> Result<(), KelivoStatus> {
    if target_handle == source_handle {
        return Err(KelivoStatus::InvalidArgument);
    }
    let source = bound_keyring_for_handle(source_handle)?;
    let target = bound_keyring_for_handle(target_handle)?;
    if source.user_id != target.user_id {
        return Err(KelivoStatus::DeviceAuthenticationFailed);
    }
    let (epoch, key) = {
        let source = source
            .keyring
            .lock()
            .map_err(|_| KelivoStatus::InternalState)?;
        if source.len() != 1 {
            return Err(KelivoStatus::InvalidArgument);
        }
        let (epoch, key) = source.entries().next().ok_or(KelivoStatus::InternalState)?;
        (epoch, crypto::AccountRootKey::from_bytes(*key.as_bytes()))
    };
    target
        .keyring
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .add_current(epoch, key)
        .map_err(|_| KelivoStatus::InvalidArgument)
}

fn prune_ark_epoch(handle: u64, epoch: u32) -> Result<(), KelivoStatus> {
    let bound = bound_keyring_for_handle(handle)?;
    bound
        .keyring
        .lock()
        .map_err(|_| KelivoStatus::InternalState)?
        .prune(epoch)
        .map_err(|_| KelivoStatus::InvalidArgument)
}

pub(super) fn close_ark(handle: u64) -> Result<(), KelivoStatus> {
    close_secret(
        ark_registry(),
        handle,
        ACCOUNT_ROOT_KEY_HANDLE_TAG,
        KelivoStatus::InvalidAccountRootKeyHandle,
    )
}

fn derive_account_record_id(
    ark: &crypto::AccountRootKey,
    canonical_entity_key: &[u8],
) -> Result<[u8; DERIVED_RECORD_ID_LENGTH], KelivoStatus> {
    if canonical_entity_key.is_empty() {
        return Err(KelivoStatus::InvalidArgument);
    }
    if canonical_entity_key.len() > RECORD_ENTITY_KEY_MAX_LENGTH {
        return Err(KelivoStatus::InputTooLarge);
    }

    let entity_key_length =
        u32::try_from(canonical_entity_key.len()).map_err(|_| KelivoStatus::InputTooLarge)?;
    let mut record_id_key = Zeroizing::new([0_u8; crypto::ACCOUNT_ROOT_KEY_LENGTH]);
    Hkdf::<Sha256>::new(None, ark.as_bytes())
        .expand(RECORD_ID_KEY_INFO, record_id_key.as_mut_slice())
        .map_err(|_| KelivoStatus::InternalState)?;
    let mut prf = <Hmac<Sha256> as HmacKeyInit>::new_from_slice(record_id_key.as_slice())
        .map_err(|_| KelivoStatus::InternalState)?;
    prf.update(RECORD_ID_PRF_DOMAIN);
    prf.update(&entity_key_length.to_be_bytes());
    prf.update(canonical_entity_key);

    let mut digest = prf.finalize().into_bytes();
    let mut record_id = [0_u8; DERIVED_RECORD_ID_LENGTH];
    record_id.copy_from_slice(&digest[..DERIVED_RECORD_ID_LENGTH]);
    digest.as_mut_slice().zeroize();
    record_id[6] = (record_id[6] & 0x0f) | 0x40;
    record_id[8] = (record_id[8] & 0x3f) | 0x80;
    Ok(record_id)
}

fn device_error_status(error: crypto::DeviceCryptoError) -> KelivoStatus {
    use crypto::DeviceCryptoError as Error;

    match error {
        Error::RandomnessUnavailable => KelivoStatus::RandomSourceFailure,
        Error::DeviceProofBindingMismatch
        | Error::DeviceProofSignatureInvalid
        | Error::ArkEnvelopeBindingMismatch
        | Error::ArkEnvelopeSignatureInvalid
        | Error::AccountTrustSignatureInvalid
        | Error::KeyAgreementKeyMismatch
        | Error::ArkEnvelopeOpenFailed
        | Error::PairingAuthenticatorInvalid => KelivoStatus::DeviceAuthenticationFailed,
        Error::InvalidDeviceStateMagic
        | Error::UnsupportedDeviceStateVersion(_)
        | Error::UnsupportedDeviceStateSuite(_)
        | Error::UnsupportedDeviceStateFlags(_)
        | Error::UnsupportedDeviceStateReserved(_)
        | Error::InvalidDeviceStateLength { .. }
        | Error::InvalidDeviceKeyVersion
        | Error::DeviceStateBindingMismatch => KelivoStatus::DeviceStateInvalid,
        Error::DeviceStateAuthenticationFailed => KelivoStatus::DeviceStateAuthenticationFailed,
        Error::DeviceStateCryptoFailed
        | Error::PairingAuthenticatorCryptoFailed
        | Error::AccountTrustKeyDerivationFailed => KelivoStatus::InternalState,
        Error::InvalidUuidV4
        | Error::InvalidExpiry
        | Error::InvalidSigningPublicKey
        | Error::InvalidKeyAgreementPublicKey
        | Error::InvalidKeyAgreementPrivateKey
        | Error::SigningKeyMismatch
        | Error::InvalidDeviceProofMagic
        | Error::UnsupportedDeviceProofVersion(_)
        | Error::UnsupportedDeviceProofKind(_)
        | Error::UnsupportedDeviceProofFlags(_)
        | Error::InvalidDeviceProofLength { .. }
        | Error::InvalidDeviceProofSignatureLength { .. }
        | Error::InvalidKeyEpoch
        | Error::ArkKeyEpochNotFound
        | Error::ArkKeyEpochNotIncreasing
        | Error::ArkKeyringCapacityExceeded
        | Error::ArkCurrentEpochRemoval
        | Error::InvalidAccountTrustPayloadLength { .. }
        | Error::InvalidAccountTrustSignatureLength { .. }
        | Error::InvalidArkEnvelopeMagic
        | Error::UnsupportedArkEnvelopeVersion(_)
        | Error::UnsupportedArkEnvelopeSuite(_)
        | Error::UnsupportedArkEnvelopeFlags(_)
        | Error::UnsupportedArkEnvelopeReserved(_)
        | Error::InvalidArkEnvelopeLength { .. }
        | Error::ArkEnvelopeSealFailed
        | Error::InvalidPrimaryPayloadLength { .. }
        | Error::InvalidEnvelopePayloadLength { .. }
        | Error::InvalidPairingAuthenticatorLength { .. } => KelivoStatus::DeviceMessageInvalid,
    }
}

unsafe fn read_fixed<const LENGTH: usize>(
    input: *const u8,
    input_length: usize,
) -> Result<[u8; LENGTH], KelivoStatus> {
    if input_length != LENGTH {
        return Err(KelivoStatus::DeviceMessageInvalid);
    }
    let input = unsafe { read_input(input, input_length) }?;
    let mut output = [0_u8; LENGTH];
    output.copy_from_slice(input);
    Ok(output)
}

unsafe fn read_device_id(
    input: *const u8,
    input_length: usize,
) -> Result<crypto::DeviceId, KelivoStatus> {
    crypto::DeviceId::new(unsafe { read_fixed(input, input_length)? }).map_err(device_error_status)
}

unsafe fn read_user_id(
    input: *const u8,
    input_length: usize,
) -> Result<crypto::UserId, KelivoStatus> {
    crypto::UserId::new(unsafe { read_fixed(input, input_length)? }).map_err(device_error_status)
}

unsafe fn read_attempt_id(
    input: *const u8,
    input_length: usize,
) -> Result<crypto::DeviceProofAttemptId, KelivoStatus> {
    crypto::DeviceProofAttemptId::new(unsafe { read_fixed(input, input_length)? })
        .map_err(device_error_status)
}

unsafe fn read_account_context_id(
    input: *const u8,
    input_length: usize,
) -> Result<crypto::AccountContextId, KelivoStatus> {
    crypto::AccountContextId::new(unsafe { read_fixed(input, input_length)? })
        .map_err(device_error_status)
}

unsafe fn read_public_keys(
    signing_key: *const u8,
    signing_key_length: usize,
    key_agreement_key: *const u8,
    key_agreement_key_length: usize,
) -> Result<crypto::DevicePublicKeys, KelivoStatus> {
    Ok(crypto::DevicePublicKeys {
        signing: crypto::DeviceSigningPublicKey::from_bytes(unsafe {
            read_fixed(signing_key, signing_key_length)?
        })
        .map_err(device_error_status)?,
        key_agreement: crypto::DeviceKeyAgreementPublicKey::from_bytes(unsafe {
            read_fixed(key_agreement_key, key_agreement_key_length)?
        })
        .map_err(device_error_status)?,
    })
}

struct EncodedProofContext {
    attempt_id: *const u8,
    attempt_id_length: usize,
    account_context_id: *const u8,
    account_context_id_length: usize,
    device_id: crypto::DeviceId,
    expires_at_ms: u64,
    challenge: *const u8,
    challenge_length: usize,
}

unsafe fn read_proof_context(
    encoded: EncodedProofContext,
) -> Result<crypto::DeviceProofContext, KelivoStatus> {
    if encoded.expires_at_ms == 0 {
        return Err(KelivoStatus::DeviceMessageInvalid);
    }
    Ok(crypto::DeviceProofContext {
        attempt_id: unsafe { read_attempt_id(encoded.attempt_id, encoded.attempt_id_length) }?,
        account_context_id: unsafe {
            read_account_context_id(
                encoded.account_context_id,
                encoded.account_context_id_length,
            )
        }?,
        device_id: encoded.device_id,
        expires_at_ms: encoded.expires_at_ms,
        challenge: crypto::DeviceProofChallenge::from_bytes(unsafe {
            read_fixed(encoded.challenge, encoded.challenge_length)?
        }),
    })
}

fn derive_state_key(key: &LocalKey) -> Result<Zeroizing<[u8; 32]>, KelivoStatus> {
    let mut state_key = Zeroizing::new([0_u8; 32]);
    Hkdf::<Sha256>::new(None, master_key(key)?)
        .expand(STATE_KEY_INFO, state_key.as_mut_slice())
        .map_err(|_| KelivoStatus::InternalState)?;
    Ok(state_key)
}

fn state_binding(
    device_id: crypto::DeviceId,
    key_version: u32,
    account: Option<(crypto::UserId, u32)>,
) -> crypto::DeviceStateBinding {
    crypto::DeviceStateBinding {
        device_id,
        key_version,
        account: account
            .map(|(user_id, key_epoch)| crypto::DeviceStateAccountBinding { user_id, key_epoch }),
    }
}

unsafe fn reset_handle(out_handle: *mut u64) -> Result<(), KelivoStatus> {
    unsafe { write_output(out_handle, INVALID_KEY_HANDLE) }
}

unsafe fn reset_device_state_open_outputs(
    out_binding: *mut KelivoDeviceStateBinding,
    out_identity_handle: *mut u64,
    out_ark_handle: *mut u64,
) -> Result<(), KelivoStatus> {
    let binding_result = unsafe { write_output(out_binding, KelivoDeviceStateBinding::empty()) };
    let identity_result = unsafe { reset_handle(out_identity_handle) };
    let ark_result = unsafe { reset_handle(out_ark_handle) };
    binding_result?;
    identity_result?;
    ark_result
}

unsafe fn reset_handle_and_length(
    out_handle: *mut u64,
    out_length: *mut usize,
) -> Result<(), KelivoStatus> {
    unsafe {
        reset_handle(out_handle)?;
        write_output(out_length, 0)
    }
}

pub(super) unsafe fn prepare_fixed_output(
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
    expected_length: usize,
) -> Result<(), KelivoStatus> {
    unsafe { write_output(output_length, 0)? };
    if output_capacity < expected_length {
        unsafe { write_output(output_length, expected_length)? };
        return Err(KelivoStatus::OutputBufferTooSmall);
    }
    if output.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    Ok(())
}

unsafe fn prepare_zeroed_fixed_output(
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
    expected_length: usize,
) -> Result<(), KelivoStatus> {
    unsafe { write_output(output_length, 0)? };
    if output_capacity < expected_length {
        if !output.is_null() && output_capacity != 0 {
            unsafe { core::ptr::write_bytes(output, 0, output_capacity) };
        }
        unsafe { write_output(output_length, expected_length)? };
        return Err(KelivoStatus::OutputBufferTooSmall);
    }
    if output.is_null() {
        return Err(KelivoStatus::NullPointer);
    }
    unsafe { core::ptr::write_bytes(output, 0, expected_length) };
    Ok(())
}

fn create_pending_pairing_at(
    identity: &crypto::DeviceIdentity,
    target_device_id: crypto::DeviceId,
    target_key_version: u32,
    now: Instant,
) -> Result<
    (
        PendingPairing,
        Zeroizing<[u8; PENDING_PAIRING_MATERIAL_LENGTH]>,
    ),
    KelivoStatus,
> {
    if target_key_version == 0 {
        return Err(KelivoStatus::DeviceStateInvalid);
    }
    let mut rng = protocol::system_rng().map_err(|_| KelivoStatus::RandomSourceFailure)?;
    let mut pairing_id_bytes = [0_u8; UUID_LENGTH];
    let mut pairing_secret = Zeroizing::new([0_u8; PAIRING_SECRET_LENGTH]);
    rng.try_fill_bytes(&mut pairing_id_bytes)
        .map_err(|_| KelivoStatus::RandomSourceFailure)?;
    rng.try_fill_bytes(pairing_secret.as_mut_slice())
        .map_err(|_| KelivoStatus::RandomSourceFailure)?;
    pairing_id_bytes[6] = (pairing_id_bytes[6] & 0x0f) | 0x40;
    pairing_id_bytes[8] = (pairing_id_bytes[8] & 0x3f) | 0x80;
    let pairing_id =
        crypto::DeviceProofAttemptId::new(pairing_id_bytes).map_err(device_error_status)?;
    let deadline = now
        .checked_add(PAIRING_LIFETIME)
        .ok_or(KelivoStatus::InternalState)?;

    let mut material = Zeroizing::new([0_u8; PENDING_PAIRING_MATERIAL_LENGTH]);
    material[..UUID_LENGTH].copy_from_slice(pairing_id.as_bytes());
    material[UUID_LENGTH..UUID_LENGTH + PAIRING_SECRET_LENGTH]
        .copy_from_slice(pairing_secret.as_slice());
    material[UUID_LENGTH + PAIRING_SECRET_LENGTH..]
        .copy_from_slice(&Sha256::digest(pairing_secret.as_slice()));
    Ok((
        PendingPairing {
            pairing_id,
            pairing_secret,
            target_device_id,
            target_key_version,
            target_public_keys: identity.public_keys(),
            deadline,
            bound: None,
        },
        material,
    ))
}

#[unsafe(no_mangle)]
/// # Safety
///
/// `out_handle` 必须指向可写的 `uint64_t`。
pub unsafe extern "C" fn kelivo_device_identity_generate(out_handle: *mut u64) -> i32 {
    if let Err(status) = unsafe { reset_handle(out_handle) } {
        return status.code();
    }
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let identity = match crypto::DeviceIdentity::generate(&mut rng) {
        Ok(identity) => identity,
        Err(error) => return device_error_status(error).code(),
    };
    let handle = match register_identity(identity) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };
    unsafe {
        write_output(out_handle, handle).expect("已验证的设备身份句柄输出必须可写")
    };
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 输出指针必须覆盖声明容量，长度指针必须可写且不得与输出缓冲区重叠。
pub unsafe extern "C" fn kelivo_device_identity_public_keys(
    identity_handle: u64,
    out_public_keys: *mut u8,
    out_public_keys_capacity: usize,
    out_public_keys_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_public_keys_length, 0) } {
        return status.code();
    }
    let identity = match identity_for_handle(identity_handle) {
        Ok(identity) => identity,
        Err(status) => return status.code(),
    };
    let public_keys = identity.public_keys();
    let mut bytes = [0_u8; DEVICE_PUBLIC_KEYS_LENGTH];
    bytes[..crypto::DEVICE_PUBLIC_KEY_LENGTH].copy_from_slice(public_keys.signing.as_bytes());
    bytes[crypto::DEVICE_PUBLIC_KEY_LENGTH..].copy_from_slice(public_keys.key_agreement.as_bytes());
    match unsafe {
        write_bytes(
            out_public_keys,
            out_public_keys_capacity,
            &bytes,
            out_public_keys_length,
        )
    } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
/// # Safety
///
/// `public_key` 必须覆盖声明长度。
pub unsafe extern "C" fn kelivo_device_signing_public_key_validate(
    public_key: *const u8,
    public_key_length: usize,
) -> i32 {
    let bytes = match unsafe { read_fixed(public_key, public_key_length) } {
        Ok(bytes) => bytes,
        Err(status) => return status.code(),
    };
    match crypto::DeviceSigningPublicKey::from_bytes(bytes) {
        Ok(_) => KelivoStatus::Ok.code(),
        Err(error) => device_error_status(error).code(),
    }
}

#[unsafe(no_mangle)]
/// # Safety
///
/// `public_key` 必须覆盖声明长度。
pub unsafe extern "C" fn kelivo_device_key_agreement_public_key_validate(
    public_key: *const u8,
    public_key_length: usize,
) -> i32 {
    let bytes = match unsafe { read_fixed(public_key, public_key_length) } {
        Ok(bytes) => bytes,
        Err(status) => return status.code(),
    };
    match crypto::DeviceKeyAgreementPublicKey::from_bytes(bytes) {
        Ok(_) => KelivoStatus::Ok.code(),
        Err(error) => device_error_status(error).code(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_device_identity_handle_close(identity_handle: u64) -> i32 {
    match close_identity(identity_handle) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出指针必须可写且不得互相重叠。
pub unsafe extern "C" fn kelivo_pending_pairing_start(
    identity_handle: u64,
    target_device_id: *const u8,
    target_device_id_length: usize,
    target_key_version: u32,
    out_pending_handle: *mut u64,
    out_material: *mut u8,
    out_material_capacity: usize,
    out_material_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { reset_handle(out_pending_handle) } {
        return status.code();
    }
    if let Err(status) = unsafe {
        prepare_fixed_output(
            out_material,
            out_material_capacity,
            out_material_length,
            PENDING_PAIRING_MATERIAL_LENGTH,
        )
    } {
        return status.code();
    }
    let target_device_id =
        match unsafe { read_device_id(target_device_id, target_device_id_length) } {
            Ok(device_id) => device_id,
            Err(status) => return status.code(),
        };
    let identity = match identity_for_handle(identity_handle) {
        Ok(identity) => identity,
        Err(status) => return status.code(),
    };
    let (pending, material) = match create_pending_pairing_at(
        &identity,
        target_device_id,
        target_key_version,
        Instant::now(),
    ) {
        Ok(created) => created,
        Err(status) => return status.code(),
    };
    let handle = match register_pending_pairing(pending) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };
    unsafe {
        write_bytes(
            out_material,
            out_material_capacity,
            material.as_slice(),
            out_material_length,
        )
        .expect("已验证的配对材料输出必须可写");
        write_output(out_pending_handle, handle).expect("已验证的 pending 句柄输出必须可写");
    }
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；函数不保留任何调用方缓冲区。
pub unsafe extern "C" fn kelivo_pending_pairing_bind(
    pending_handle: u64,
    protocol_version: u32,
    pairing_id: *const u8,
    pairing_id_length: usize,
    user_id: *const u8,
    user_id_length: usize,
    target_device_id: *const u8,
    target_device_id_length: usize,
    target_key_version: u32,
    target_signing_public_key: *const u8,
    target_signing_public_key_length: usize,
    target_key_agreement_public_key: *const u8,
    target_key_agreement_public_key_length: usize,
    expires_at_ms: u64,
    challenge: *const u8,
    challenge_length: usize,
    now_ms: u64,
) -> i32 {
    let pairing_id = match unsafe { read_attempt_id(pairing_id, pairing_id_length) } {
        Ok(pairing_id) => pairing_id,
        Err(status) => return status.code(),
    };
    let user_id = match unsafe { read_user_id(user_id, user_id_length) } {
        Ok(user_id) => user_id,
        Err(status) => return status.code(),
    };
    let target_device_id =
        match unsafe { read_device_id(target_device_id, target_device_id_length) } {
            Ok(device_id) => device_id,
            Err(status) => return status.code(),
        };
    let target_public_keys = match unsafe {
        read_public_keys(
            target_signing_public_key,
            target_signing_public_key_length,
            target_key_agreement_public_key,
            target_key_agreement_public_key_length,
        )
    } {
        Ok(public_keys) => public_keys,
        Err(status) => return status.code(),
    };
    let challenge = match unsafe { read_fixed(challenge, challenge_length) } {
        Ok(challenge) => crypto::DeviceProofChallenge::from_bytes(challenge),
        Err(status) => return status.code(),
    };
    match bind_pending_pairing_at(
        pending_handle,
        PairingBindInput {
            protocol_version,
            pairing_id,
            user_id,
            target_device_id,
            target_key_version,
            target_public_keys,
            expires_at_ms,
            challenge,
        },
        now_ms,
        Instant::now(),
    ) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_pending_pairing_handle_close(pending_handle: u64) -> i32 {
    match close_pending_pairing(pending_handle) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
/// # Safety
///
/// `out_handle` 必须指向可写的 `uint64_t`。
pub unsafe extern "C" fn kelivo_account_root_key_generate(
    user_id: *const u8,
    user_id_length: usize,
    key_epoch: u32,
    out_handle: *mut u64,
) -> i32 {
    if let Err(status) = unsafe { reset_handle(out_handle) } {
        return status.code();
    }
    if key_epoch == 0 {
        return KelivoStatus::InvalidArgument.code();
    }
    let user_id = match unsafe { read_user_id(user_id, user_id_length) } {
        Ok(user_id) => user_id,
        Err(status) => return status.code(),
    };
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let ark = match crypto::AccountRootKey::generate(&mut rng) {
        Ok(ark) => ark,
        Err(error) => return device_error_status(error).code(),
    };
    let handle = match register_ark(user_id, key_epoch, ark) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };
    unsafe { write_output(out_handle, handle).expect("已验证的 ARK 句柄输出必须可写") };
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// `canonical_entity_key` 必须覆盖声明长度，`key_epoch` 必须为正数；输出指针
/// 必须覆盖声明容量，长度指针必须可写，且所有缓冲区不得重叠。
pub unsafe extern "C" fn kelivo_account_record_id_derive(
    ark_handle: u64,
    canonical_entity_key: *const u8,
    canonical_entity_key_length: usize,
    key_epoch: u32,
    out_record_id: *mut u8,
    out_record_id_capacity: usize,
    out_record_id_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        prepare_fixed_output(
            out_record_id,
            out_record_id_capacity,
            out_record_id_length,
            DERIVED_RECORD_ID_LENGTH,
        )
    } {
        return status.code();
    }
    if key_epoch == 0 || canonical_entity_key_length == 0 {
        return KelivoStatus::InvalidArgument.code();
    }
    if canonical_entity_key_length > RECORD_ENTITY_KEY_MAX_LENGTH {
        return KelivoStatus::InputTooLarge.code();
    }
    let canonical_entity_key =
        match unsafe { read_input(canonical_entity_key, canonical_entity_key_length) } {
            Ok(value) => value,
            Err(status) => return status.code(),
        };
    let bound = match bound_keyring_for_handle(ark_handle) {
        Ok(bound) => bound,
        Err(status) => return status.code(),
    };
    let record_id = match with_ark_for_bound_keyring(&bound, key_epoch, |ark| {
        derive_account_record_id(ark, canonical_entity_key)
    }) {
        Ok(record_id) => record_id,
        Err(status) => return status.code(),
    };
    unsafe {
        write_bytes(
            out_record_id,
            out_record_id_capacity,
            &record_id,
            out_record_id_length,
        )
        .expect("已验证的不透明记录 ID 输出必须可写");
    }
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// `user_id` 必须覆盖声明长度；输出缓冲区与长度指针必须可写且互不重叠。
pub unsafe extern "C" fn kelivo_account_trust_public_key_derive(
    ark_handle: u64,
    user_id: *const u8,
    user_id_length: usize,
    key_epoch: u32,
    out_public_key: *mut u8,
    out_public_key_capacity: usize,
    out_public_key_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        prepare_zeroed_fixed_output(
            out_public_key,
            out_public_key_capacity,
            out_public_key_length,
            ACCOUNT_TRUST_PUBLIC_KEY_LENGTH,
        )
    } {
        return status.code();
    }
    if key_epoch == 0 {
        return KelivoStatus::InvalidArgument.code();
    }
    let user_id = match unsafe { read_user_id(user_id, user_id_length) } {
        Ok(user_id) => user_id,
        Err(status) => return status.code(),
    };
    let binding = crypto::AccountTrustBinding { user_id, key_epoch };
    let public_key = match with_ark_for_account_handle(ark_handle, user_id, key_epoch, |ark| {
        crypto::derive_account_trust_public_key(ark, binding).map_err(device_error_status)
    }) {
        Ok(public_key) => public_key,
        Err(status) => return status.code(),
    };
    unsafe {
        write_bytes(
            out_public_key,
            out_public_key_capacity,
            public_key.as_bytes(),
            out_public_key_length,
        )
        .expect("已清零且验证的账户信任根公钥输出必须可写")
    };
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出缓冲区与长度指针必须可写且互不重叠。
pub unsafe extern "C" fn kelivo_account_trust_payload_sign(
    ark_handle: u64,
    user_id: *const u8,
    user_id_length: usize,
    key_epoch: u32,
    canonical_payload: *const u8,
    canonical_payload_length: usize,
    out_signature: *mut u8,
    out_signature_capacity: usize,
    out_signature_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        prepare_zeroed_fixed_output(
            out_signature,
            out_signature_capacity,
            out_signature_length,
            ACCOUNT_TRUST_SIGNATURE_LENGTH,
        )
    } {
        return status.code();
    }
    if key_epoch == 0 {
        return KelivoStatus::InvalidArgument.code();
    }
    let user_id = match unsafe { read_user_id(user_id, user_id_length) } {
        Ok(user_id) => user_id,
        Err(status) => return status.code(),
    };
    let canonical_payload =
        match unsafe { read_account_trust_payload(canonical_payload, canonical_payload_length) } {
            Ok(payload) => payload,
            Err(status) => return status.code(),
        };
    let binding = crypto::AccountTrustBinding { user_id, key_epoch };
    let signature = match with_ark_for_account_handle(ark_handle, user_id, key_epoch, |ark| {
        crypto::sign_account_trust_payload(ark, binding, canonical_payload)
            .map_err(device_error_status)
    }) {
        Ok(signature) => signature,
        Err(status) => return status.code(),
    };
    unsafe {
        write_bytes(
            out_signature,
            out_signature_capacity,
            signature.as_bytes(),
            out_signature_length,
        )
        .expect("已清零且验证的账户信任根签名输出必须可写")
    };
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度。验证钥必须来自本地已认证 ARK 的派生结果，
/// 该函数本身只验证密码学签名，不建立验证钥的信任来源。
pub unsafe extern "C" fn kelivo_account_trust_payload_verify(
    public_key: *const u8,
    public_key_length: usize,
    user_id: *const u8,
    user_id_length: usize,
    key_epoch: u32,
    canonical_payload: *const u8,
    canonical_payload_length: usize,
    signature: *const u8,
    signature_length: usize,
) -> i32 {
    if key_epoch == 0 {
        return KelivoStatus::InvalidArgument.code();
    }
    let public_key = match unsafe { read_fixed(public_key, public_key_length) } {
        Ok(bytes) => match crypto::AccountTrustPublicKey::from_bytes(bytes) {
            Ok(public_key) => public_key,
            Err(error) => return device_error_status(error).code(),
        },
        Err(status) => return status.code(),
    };
    let user_id = match unsafe { read_user_id(user_id, user_id_length) } {
        Ok(user_id) => user_id,
        Err(status) => return status.code(),
    };
    let canonical_payload =
        match unsafe { read_account_trust_payload(canonical_payload, canonical_payload_length) } {
            Ok(payload) => payload,
            Err(status) => return status.code(),
        };
    let signature = match unsafe { read_input(signature, signature_length) } {
        Ok(bytes) => match crypto::AccountTrustSignature::from_bytes(bytes) {
            Ok(signature) => signature,
            Err(error) => return device_error_status(error).code(),
        },
        Err(status) => return status.code(),
    };
    match crypto::verify_account_trust_payload(
        &public_key,
        crypto::AccountTrustBinding { user_id, key_epoch },
        canonical_payload,
        &signature,
    ) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(error) => device_error_status(error).code(),
    }
}

unsafe fn read_account_trust_payload<'a>(
    input: *const u8,
    input_length: usize,
) -> Result<&'a [u8], KelivoStatus> {
    if input_length == 0 {
        return Err(KelivoStatus::InvalidArgument);
    }
    if input_length > ACCOUNT_TRUST_PAYLOAD_MAX_LENGTH {
        return Err(KelivoStatus::InputTooLarge);
    }
    unsafe { read_input(input, input_length) }
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_account_root_key_handle_close(ark_handle: u64) -> i32 {
    match close_ark(ark_handle) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_account_root_keyring_add_epoch(
    target_ark_handle: u64,
    source_ark_handle: u64,
) -> i32 {
    match merge_ark_epoch(target_ark_handle, source_ark_handle) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn kelivo_account_root_keyring_prune_epoch(ark_handle: u64, key_epoch: u32) -> i32 {
    match prune_ark_epoch(ark_handle, key_epoch) {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出缓冲区和长度指针必须可写且互不重叠。
pub unsafe extern "C" fn kelivo_account_root_key_envelope_seal(
    issuer_identity_handle: u64,
    ark_handle: u64,
    user_id: *const u8,
    user_id_length: usize,
    issuer_device_id: *const u8,
    issuer_device_id_length: usize,
    target_device_id: *const u8,
    target_device_id_length: usize,
    key_epoch: u32,
    target_signing_public_key: *const u8,
    target_signing_public_key_length: usize,
    target_key_agreement_public_key: *const u8,
    target_key_agreement_public_key_length: usize,
    out_envelope: *mut u8,
    out_envelope_capacity: usize,
    out_envelope_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        prepare_zeroed_fixed_output(
            out_envelope,
            out_envelope_capacity,
            out_envelope_length,
            crypto::ARK_ENVELOPE_LENGTH,
        )
    } {
        return status.code();
    }
    if key_epoch == 0 {
        return KelivoStatus::DeviceMessageInvalid.code();
    }
    let user_id = match unsafe { read_user_id(user_id, user_id_length) } {
        Ok(user_id) => user_id,
        Err(status) => return status.code(),
    };
    let issuer_device_id =
        match unsafe { read_device_id(issuer_device_id, issuer_device_id_length) } {
            Ok(device_id) => device_id,
            Err(status) => return status.code(),
        };
    let target_device_id =
        match unsafe { read_device_id(target_device_id, target_device_id_length) } {
            Ok(device_id) => device_id,
            Err(status) => return status.code(),
        };
    let target_public_keys = match unsafe {
        read_public_keys(
            target_signing_public_key,
            target_signing_public_key_length,
            target_key_agreement_public_key,
            target_key_agreement_public_key_length,
        )
    } {
        Ok(public_keys) => public_keys,
        Err(status) => return status.code(),
    };
    let identity = match identity_for_handle(issuer_identity_handle) {
        Ok(identity) => identity,
        Err(status) => return status.code(),
    };
    let ark = match ark_for_account_handle(ark_handle, user_id, key_epoch) {
        Ok(ark) => ark,
        Err(status) => return status.code(),
    };
    let issuer_public_keys = identity.public_keys();
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let envelope = match identity.seal_ark_envelope(
        &mut rng,
        &ark,
        crypto::ArkEnvelopeBinding {
            user_id,
            issuer_device_id,
            target_device_id,
            key_epoch,
            issuer_signing_public_key: issuer_public_keys.signing,
            issuer_key_agreement_public_key: issuer_public_keys.key_agreement,
            target_signing_public_key: target_public_keys.signing,
            target_key_agreement_public_key: target_public_keys.key_agreement,
        },
    ) {
        Ok(envelope) => envelope,
        Err(error) => return device_error_status(error).code(),
    };
    unsafe {
        write_bytes(
            out_envelope,
            out_envelope_capacity,
            envelope.as_bytes(),
            out_envelope_length,
        )
        .expect("已清零且验证的 ARK 信封输出必须可写")
    };
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；`out_ark_handle` 必须指向可写的 `uint64_t`。
pub unsafe extern "C" fn kelivo_account_root_key_envelope_open(
    target_identity_handle: u64,
    envelope: *const u8,
    envelope_length: usize,
    user_id: *const u8,
    user_id_length: usize,
    issuer_device_id: *const u8,
    issuer_device_id_length: usize,
    target_device_id: *const u8,
    target_device_id_length: usize,
    key_epoch: u32,
    issuer_signing_public_key: *const u8,
    issuer_signing_public_key_length: usize,
    issuer_key_agreement_public_key: *const u8,
    issuer_key_agreement_public_key_length: usize,
    target_signing_public_key: *const u8,
    target_signing_public_key_length: usize,
    target_key_agreement_public_key: *const u8,
    target_key_agreement_public_key_length: usize,
    out_ark_handle: *mut u64,
) -> i32 {
    if let Err(status) = unsafe { reset_handle(out_ark_handle) } {
        return status.code();
    }
    if key_epoch == 0 {
        return KelivoStatus::DeviceMessageInvalid.code();
    }
    if envelope_length != crypto::ARK_ENVELOPE_LENGTH {
        return KelivoStatus::DeviceMessageInvalid.code();
    }
    let envelope = match unsafe { read_input(envelope, envelope_length) } {
        Ok(envelope) => envelope,
        Err(status) => return status.code(),
    };
    let user_id = match unsafe { read_user_id(user_id, user_id_length) } {
        Ok(user_id) => user_id,
        Err(status) => return status.code(),
    };
    let issuer_device_id =
        match unsafe { read_device_id(issuer_device_id, issuer_device_id_length) } {
            Ok(device_id) => device_id,
            Err(status) => return status.code(),
        };
    let target_device_id =
        match unsafe { read_device_id(target_device_id, target_device_id_length) } {
            Ok(device_id) => device_id,
            Err(status) => return status.code(),
        };
    let issuer_public_keys = match unsafe {
        read_public_keys(
            issuer_signing_public_key,
            issuer_signing_public_key_length,
            issuer_key_agreement_public_key,
            issuer_key_agreement_public_key_length,
        )
    } {
        Ok(public_keys) => public_keys,
        Err(status) => return status.code(),
    };
    let target_public_keys = match unsafe {
        read_public_keys(
            target_signing_public_key,
            target_signing_public_key_length,
            target_key_agreement_public_key,
            target_key_agreement_public_key_length,
        )
    } {
        Ok(public_keys) => public_keys,
        Err(status) => return status.code(),
    };
    let identity = match identity_for_handle(target_identity_handle) {
        Ok(identity) => identity,
        Err(status) => return status.code(),
    };
    if identity.public_keys() != target_public_keys {
        return KelivoStatus::DeviceAuthenticationFailed.code();
    }
    let ark = match identity.open_ark_envelope(
        envelope,
        crypto::ArkEnvelopeBinding {
            user_id,
            issuer_device_id,
            target_device_id,
            key_epoch,
            issuer_signing_public_key: issuer_public_keys.signing,
            issuer_key_agreement_public_key: issuer_public_keys.key_agreement,
            target_signing_public_key: target_public_keys.signing,
            target_key_agreement_public_key: target_public_keys.key_agreement,
        },
    ) {
        Ok(ark) => ark,
        Err(error) => return device_error_status(error).code(),
    };
    let ark_handle = match register_ark(user_id, key_epoch, ark) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };
    unsafe {
        write_output(out_ark_handle, ark_handle).expect("已验证的轮换 ARK 句柄输出必须可写")
    };
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出缓冲区和长度指针必须可写且互不重叠。
pub unsafe extern "C" fn kelivo_device_login_proof_sign(
    identity_handle: u64,
    attempt_id: *const u8,
    attempt_id_length: usize,
    account_context_id: *const u8,
    account_context_id_length: usize,
    device_id: *const u8,
    device_id_length: usize,
    expires_at_ms: u64,
    challenge: *const u8,
    challenge_length: usize,
    credential_finalization: *const u8,
    credential_finalization_length: usize,
    out_signature: *mut u8,
    out_signature_capacity: usize,
    out_signature_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_signature_length, 0) } {
        return status.code();
    }
    if credential_finalization_length != protocol::CREDENTIAL_FINALIZATION_LENGTH {
        return KelivoStatus::DeviceMessageInvalid.code();
    }
    let device_id = match unsafe { read_device_id(device_id, device_id_length) } {
        Ok(device_id) => device_id,
        Err(status) => return status.code(),
    };
    let context = match unsafe {
        read_proof_context(EncodedProofContext {
            attempt_id,
            attempt_id_length,
            account_context_id,
            account_context_id_length,
            device_id,
            expires_at_ms,
            challenge,
            challenge_length,
        })
    } {
        Ok(context) => context,
        Err(status) => return status.code(),
    };
    let finalization =
        match unsafe { read_input(credential_finalization, credential_finalization_length) } {
            Ok(finalization) => finalization,
            Err(status) => return status.code(),
        };
    let identity = match identity_for_handle(identity_handle) {
        Ok(identity) => identity,
        Err(status) => return status.code(),
    };
    let signature = match identity.sign_opaque_finish_proof(
        crypto::DeviceProofKind::LoginFinish,
        context,
        finalization,
        &[],
    ) {
        Ok(signature) => signature,
        Err(error) => return device_error_status(error).code(),
    };
    match unsafe {
        write_bytes(
            out_signature,
            out_signature_capacity,
            signature.as_bytes(),
            out_signature_length,
        )
    } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

unsafe fn read_optional_account_binding(
    user_id: *const u8,
    user_id_length: usize,
    key_epoch: u32,
) -> Result<Option<(crypto::UserId, u32)>, KelivoStatus> {
    if user_id_length == 0 && key_epoch == 0 {
        if !user_id.is_null() {
            return Err(KelivoStatus::DeviceStateInvalid);
        }
        return Ok(None);
    }
    if user_id_length != UUID_LENGTH || key_epoch == 0 {
        return Err(KelivoStatus::DeviceStateInvalid);
    }
    Ok(Some((
        unsafe { read_user_id(user_id, user_id_length) }?,
        key_epoch,
    )))
}

fn seal_state_value(
    key: &LocalKey,
    identity: &crypto::DeviceIdentity,
    keyring: Option<&crypto::AccountRootKeyring>,
    binding: crypto::DeviceStateBinding,
) -> Result<crypto::DeviceStateBlob, KelivoStatus> {
    let state_key = derive_state_key(key)?;
    let mut rng = protocol::system_rng().map_err(|_| KelivoStatus::RandomSourceFailure)?;
    crypto::seal_device_state(&mut rng, &state_key, identity, keyring, binding)
        .map_err(device_error_status)
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出缓冲区和长度指针必须可写且互不重叠。
pub unsafe extern "C" fn kelivo_device_state_seal(
    key_handle: u64,
    identity_handle: u64,
    ark_handle: u64,
    device_id: *const u8,
    device_id_length: usize,
    key_version: u32,
    user_id: *const u8,
    user_id_length: usize,
    key_epoch: u32,
    out_blob: *mut u8,
    out_blob_capacity: usize,
    out_blob_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { write_output(out_blob_length, 0) } {
        return status.code();
    }
    let device_id = match unsafe { read_device_id(device_id, device_id_length) } {
        Ok(device_id) => device_id,
        Err(status) => return status.code(),
    };
    let account = match unsafe { read_optional_account_binding(user_id, user_id_length, key_epoch) }
    {
        Ok(account) => account,
        Err(status) => return status.code(),
    };
    if (ark_handle == INVALID_KEY_HANDLE) != account.is_none() {
        return KelivoStatus::DeviceStateInvalid.code();
    }
    let key = match key_for_handle(key_handle) {
        Ok(key) => key,
        Err(status) => return status.code(),
    };
    let identity = match identity_for_handle(identity_handle) {
        Ok(identity) => identity,
        Err(status) => return status.code(),
    };
    let keyring = if ark_handle == INVALID_KEY_HANDLE {
        None
    } else {
        let (user_id, key_epoch) = account.expect("已验证的账户绑定必须存在");
        match keyring_snapshot_for_handle(ark_handle, user_id, key_epoch) {
            Ok(keyring) => Some(keyring),
            Err(status) => return status.code(),
        }
    };
    let binding = state_binding(device_id, key_version, account);
    let blob = match seal_state_value(&key, &identity, keyring.as_ref(), binding) {
        Ok(blob) => blob,
        Err(status) => return status.code(),
    };
    match unsafe {
        write_bytes(
            out_blob,
            out_blob_capacity,
            blob.as_bytes(),
            out_blob_length,
        )
    } {
        Ok(()) => KelivoStatus::Ok.code(),
        Err(status) => status.code(),
    }
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 输入指针必须覆盖声明长度；三个输出指针必须可写且彼此不得重叠。
pub unsafe extern "C" fn kelivo_device_state_open(
    key_handle: u64,
    blob: *const u8,
    blob_length: usize,
    out_binding: *mut KelivoDeviceStateBinding,
    out_identity_handle: *mut u64,
    out_ark_handle: *mut u64,
) -> i32 {
    if let Err(status) =
        unsafe { reset_device_state_open_outputs(out_binding, out_identity_handle, out_ark_handle) }
    {
        return status.code();
    }
    if blob_length != DEVICE_STATE_BLOB_LENGTH {
        return KelivoStatus::DeviceStateInvalid.code();
    }
    let blob = match unsafe { read_input(blob, blob_length) } {
        Ok(bytes) => match crypto::DeviceStateBlob::from_bytes(bytes) {
            Ok(blob) => blob,
            Err(error) => return device_error_status(error).code(),
        },
        Err(status) => return status.code(),
    };
    let key = match key_for_handle(key_handle) {
        Ok(key) => key,
        Err(status) => return status.code(),
    };
    let state_key = match derive_state_key(&key) {
        Ok(key) => key,
        Err(status) => return status.code(),
    };
    let (binding, identity, keyring) = match crypto::open_device_state(&state_key, &blob) {
        Ok(opened) => opened,
        Err(error) => return device_error_status(error).code(),
    };
    let authenticated_binding = KelivoDeviceStateBinding::authenticated(binding);

    let identity_handle = match register_identity(identity) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };
    let account_user_id = binding.account.map(|account| account.user_id);
    let ark_handle = match (keyring, account_user_id) {
        (Some(keyring), Some(user_id)) => match register_keyring(user_id, keyring) {
            Ok(handle) => handle,
            Err(status) => {
                let _ = close_identity(identity_handle);
                return status.code();
            }
        },
        (None, None) => INVALID_KEY_HANDLE,
        _ => {
            let _ = close_identity(identity_handle);
            return KelivoStatus::DeviceStateInvalid.code();
        }
    };
    unsafe {
        write_output(out_binding, authenticated_binding).expect("已验证的设备状态绑定输出必须可写");
        write_output(out_identity_handle, identity_handle)
            .expect("已验证的设备身份句柄输出必须可写");
        write_output(out_ark_handle, ark_handle).expect("已验证的 ARK 句柄输出必须可写");
    }
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出缓冲区和长度指针必须可写且互不重叠。
pub unsafe extern "C" fn kelivo_device_registration_finish_create(
    identity_handle: u64,
    ark_handle: u64,
    user_id: *const u8,
    user_id_length: usize,
    device_id: *const u8,
    device_id_length: usize,
    key_epoch: u32,
    attempt_id: *const u8,
    attempt_id_length: usize,
    account_context_id: *const u8,
    account_context_id_length: usize,
    expires_at_ms: u64,
    challenge: *const u8,
    challenge_length: usize,
    registration_upload: *const u8,
    registration_upload_length: usize,
    out_bundle: *mut u8,
    out_bundle_capacity: usize,
    out_bundle_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        prepare_fixed_output(
            out_bundle,
            out_bundle_capacity,
            out_bundle_length,
            REGISTRATION_FINISH_BUNDLE_LENGTH,
        )
    } {
        return status.code();
    }
    if registration_upload_length != protocol::REGISTRATION_UPLOAD_LENGTH {
        return KelivoStatus::DeviceMessageInvalid.code();
    }
    let user_id = match unsafe { read_user_id(user_id, user_id_length) } {
        Ok(user_id) => user_id,
        Err(status) => return status.code(),
    };
    let device_id = match unsafe { read_device_id(device_id, device_id_length) } {
        Ok(device_id) => device_id,
        Err(status) => return status.code(),
    };
    let context = match unsafe {
        read_proof_context(EncodedProofContext {
            attempt_id,
            attempt_id_length,
            account_context_id,
            account_context_id_length,
            device_id,
            expires_at_ms,
            challenge,
            challenge_length,
        })
    } {
        Ok(context) => context,
        Err(status) => return status.code(),
    };
    let upload = match unsafe { read_input(registration_upload, registration_upload_length) } {
        Ok(upload) => upload,
        Err(status) => return status.code(),
    };
    let identity = match identity_for_handle(identity_handle) {
        Ok(identity) => identity,
        Err(status) => return status.code(),
    };
    let ark = match ark_for_account_handle(ark_handle, user_id, key_epoch) {
        Ok(ark) => ark,
        Err(status) => return status.code(),
    };
    let public_keys = identity.public_keys();
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let envelope = match identity.seal_ark_envelope(
        &mut rng,
        &ark,
        crypto::ArkEnvelopeBinding {
            user_id,
            issuer_device_id: device_id,
            target_device_id: device_id,
            key_epoch,
            issuer_signing_public_key: public_keys.signing,
            issuer_key_agreement_public_key: public_keys.key_agreement,
            target_signing_public_key: public_keys.signing,
            target_key_agreement_public_key: public_keys.key_agreement,
        },
    ) {
        Ok(envelope) => envelope,
        Err(error) => return device_error_status(error).code(),
    };
    let signature = match identity.sign_opaque_finish_proof(
        crypto::DeviceProofKind::RegistrationFinish,
        context,
        upload,
        envelope.as_bytes(),
    ) {
        Ok(signature) => signature,
        Err(error) => return device_error_status(error).code(),
    };
    let mut bundle = [0_u8; REGISTRATION_FINISH_BUNDLE_LENGTH];
    bundle[..crypto::ARK_ENVELOPE_LENGTH].copy_from_slice(envelope.as_bytes());
    bundle[crypto::ARK_ENVELOPE_LENGTH..].copy_from_slice(signature.as_bytes());
    unsafe {
        write_bytes(out_bundle, out_bundle_capacity, &bundle, out_bundle_length)
            .expect("已验证的注册完成输出必须可写")
    };
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出缓冲区和长度指针必须可写且互不重叠。
pub unsafe extern "C" fn kelivo_device_pairing_approval_create(
    identity_handle: u64,
    ark_handle: u64,
    pairing_id: *const u8,
    pairing_id_length: usize,
    user_id: *const u8,
    user_id_length: usize,
    issuer_device_id: *const u8,
    issuer_device_id_length: usize,
    target_device_id: *const u8,
    target_device_id_length: usize,
    expires_at_ms: u64,
    challenge: *const u8,
    challenge_length: usize,
    key_epoch: u32,
    target_signing_public_key: *const u8,
    target_signing_public_key_length: usize,
    target_key_agreement_public_key: *const u8,
    target_key_agreement_public_key_length: usize,
    pairing_secret: *const u8,
    pairing_secret_length: usize,
    out_bundle: *mut u8,
    out_bundle_capacity: usize,
    out_bundle_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe {
        prepare_fixed_output(
            out_bundle,
            out_bundle_capacity,
            out_bundle_length,
            PAIRING_APPROVAL_BUNDLE_LENGTH,
        )
    } {
        return status.code();
    }
    let pairing_id = match unsafe { read_attempt_id(pairing_id, pairing_id_length) } {
        Ok(pairing_id) => pairing_id,
        Err(status) => return status.code(),
    };
    let user_id = match unsafe { read_user_id(user_id, user_id_length) } {
        Ok(user_id) => user_id,
        Err(status) => return status.code(),
    };
    let issuer_device_id =
        match unsafe { read_device_id(issuer_device_id, issuer_device_id_length) } {
            Ok(device_id) => device_id,
            Err(status) => return status.code(),
        };
    let target_device_id =
        match unsafe { read_device_id(target_device_id, target_device_id_length) } {
            Ok(device_id) => device_id,
            Err(status) => return status.code(),
        };
    let target_public_keys = match unsafe {
        read_public_keys(
            target_signing_public_key,
            target_signing_public_key_length,
            target_key_agreement_public_key,
            target_key_agreement_public_key_length,
        )
    } {
        Ok(public_keys) => public_keys,
        Err(status) => return status.code(),
    };
    let challenge = match unsafe { read_fixed(challenge, challenge_length) } {
        Ok(challenge) => crypto::DeviceProofChallenge::from_bytes(challenge),
        Err(status) => return status.code(),
    };
    let pairing_secret =
        match unsafe { read_fixed::<PAIRING_SECRET_LENGTH>(pairing_secret, pairing_secret_length) }
        {
            Ok(secret) => Zeroizing::new(secret),
            Err(status) => return status.code(),
        };
    let identity = match identity_for_handle(identity_handle) {
        Ok(identity) => identity,
        Err(status) => return status.code(),
    };
    let ark = match ark_for_account_handle(ark_handle, user_id, key_epoch) {
        Ok(ark) => ark,
        Err(status) => return status.code(),
    };
    let issuer_public_keys = identity.public_keys();
    let mut rng = match protocol::system_rng() {
        Ok(rng) => rng,
        Err(_) => return KelivoStatus::RandomSourceFailure.code(),
    };
    let envelope = match identity.seal_ark_envelope(
        &mut rng,
        &ark,
        crypto::ArkEnvelopeBinding {
            user_id,
            issuer_device_id,
            target_device_id,
            key_epoch,
            issuer_signing_public_key: issuer_public_keys.signing,
            issuer_key_agreement_public_key: issuer_public_keys.key_agreement,
            target_signing_public_key: target_public_keys.signing,
            target_key_agreement_public_key: target_public_keys.key_agreement,
        },
    ) {
        Ok(envelope) => envelope,
        Err(error) => return device_error_status(error).code(),
    };
    let (signature, authenticator) = match identity.sign_pairing_approval_proof(
        crypto::DeviceProofContext {
            attempt_id: pairing_id,
            account_context_id: match crypto::AccountContextId::new(*user_id.as_bytes()) {
                Ok(id) => id,
                Err(error) => return device_error_status(error).code(),
            },
            device_id: issuer_device_id,
            expires_at_ms,
            challenge,
        },
        pairing_secret.as_slice(),
        &envelope,
    ) {
        Ok(result) => result,
        Err(error) => return device_error_status(error).code(),
    };
    let signature_offset = crypto::ARK_ENVELOPE_LENGTH;
    let authenticator_offset = signature_offset + crypto::DEVICE_PROOF_SIGNATURE_LENGTH;
    let mut bundle = [0_u8; PAIRING_APPROVAL_BUNDLE_LENGTH];
    bundle[..signature_offset].copy_from_slice(envelope.as_bytes());
    bundle[signature_offset..authenticator_offset].copy_from_slice(signature.as_bytes());
    bundle[authenticator_offset..].copy_from_slice(authenticator.as_bytes());
    unsafe {
        write_bytes(out_bundle, out_bundle_capacity, &bundle, out_bundle_length)
            .expect("已验证的配对批准输出必须可写")
    };
    KelivoStatus::Ok.code()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// 所有输入指针必须覆盖声明长度；输出指针必须可写且不得与输入或彼此重叠。
pub unsafe extern "C" fn kelivo_device_pairing_approval_accept(
    key_handle: u64,
    identity_handle: u64,
    pending_handle: u64,
    now_ms: u64,
    issuer_device_id: *const u8,
    issuer_device_id_length: usize,
    key_epoch: u32,
    issuer_signing_public_key: *const u8,
    issuer_signing_public_key_length: usize,
    issuer_key_agreement_public_key: *const u8,
    issuer_key_agreement_public_key_length: usize,
    signature: *const u8,
    signature_length: usize,
    authenticator: *const u8,
    authenticator_length: usize,
    envelope: *const u8,
    envelope_length: usize,
    out_ark_handle: *mut u64,
    out_state_blob: *mut u8,
    out_state_blob_capacity: usize,
    out_state_blob_length: *mut usize,
) -> i32 {
    if let Err(status) = unsafe { reset_handle_and_length(out_ark_handle, out_state_blob_length) } {
        return status.code();
    }
    if let Err(status) = unsafe {
        prepare_fixed_output(
            out_state_blob,
            out_state_blob_capacity,
            out_state_blob_length,
            DEVICE_STATE_BLOB_LENGTH,
        )
    } {
        return status.code();
    }
    if signature_length != crypto::DEVICE_PROOF_SIGNATURE_LENGTH
        || authenticator_length != crypto::PAIRING_AUTHENTICATOR_LENGTH
        || envelope_length != crypto::ARK_ENVELOPE_LENGTH
    {
        return KelivoStatus::DeviceMessageInvalid.code();
    }
    let issuer_device_id =
        match unsafe { read_device_id(issuer_device_id, issuer_device_id_length) } {
            Ok(device_id) => device_id,
            Err(status) => return status.code(),
        };
    let issuer_public_keys = match unsafe {
        read_public_keys(
            issuer_signing_public_key,
            issuer_signing_public_key_length,
            issuer_key_agreement_public_key,
            issuer_key_agreement_public_key_length,
        )
    } {
        Ok(public_keys) => public_keys,
        Err(status) => return status.code(),
    };
    let signature = match unsafe { read_input(signature, signature_length) } {
        Ok(signature) => signature,
        Err(status) => return status.code(),
    };
    let authenticator = match unsafe { read_input(authenticator, authenticator_length) } {
        Ok(authenticator) => authenticator,
        Err(status) => return status.code(),
    };
    let envelope = match unsafe { read_input(envelope, envelope_length) } {
        Ok(envelope) => envelope,
        Err(status) => return status.code(),
    };
    let key = match key_for_handle(key_handle) {
        Ok(key) => key,
        Err(status) => return status.code(),
    };
    let identity = match identity_for_handle(identity_handle) {
        Ok(identity) => identity,
        Err(status) => return status.code(),
    };
    let permit = match claim_pending_pairing_at(pending_handle, now_ms, Instant::now()) {
        Ok(permit) => permit,
        Err(status) => return status.code(),
    };
    let pending = permit.pending();
    if identity.public_keys() != pending.target_public_keys {
        return KelivoStatus::DeviceAuthenticationFailed.code();
    }
    let bound = pending
        .bound
        .expect("认领 pending 时已经验证配对上下文完成绑定");
    let ark = match identity.open_pairing_approval(
        crypto::PairingApprovalExpected {
            pairing_id: pending.pairing_id,
            user_id: bound.user_id,
            issuer_device_id,
            target_device_id: pending.target_device_id,
            expires_at_ms: bound.expires_at_ms,
            challenge: bound.challenge,
            key_epoch,
            issuer_public_keys,
        },
        pending.pairing_secret.as_slice(),
        signature,
        authenticator,
        envelope,
    ) {
        Ok(ark) => ark,
        Err(error) => return device_error_status(error).code(),
    };
    let keyring = match crypto::AccountRootKeyring::new(key_epoch, ark) {
        Ok(keyring) => keyring,
        Err(error) => return device_error_status(error).code(),
    };
    let binding = state_binding(
        pending.target_device_id,
        pending.target_key_version,
        Some((bound.user_id, key_epoch)),
    );
    let blob = match seal_state_value(&key, &identity, Some(&keyring), binding) {
        Ok(blob) => blob,
        Err(status) => return status.code(),
    };
    let ark_handle = match register_keyring(bound.user_id, keyring) {
        Ok(handle) => handle,
        Err(status) => return status.code(),
    };
    permit.commit();
    unsafe {
        write_bytes(
            out_state_blob,
            out_state_blob_capacity,
            blob.as_bytes(),
            out_state_blob_length,
        )
        .expect("已验证的配对状态输出必须可写");
        write_output(out_ark_handle, ark_handle).expect("已验证的配对 ARK 句柄输出必须可写");
    }
    KelivoStatus::Ok.code()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn uuid_v4(seed: u8) -> [u8; UUID_LENGTH] {
        let mut bytes = [seed; UUID_LENGTH];
        bytes[6] = (bytes[6] & 0x0f) | 0x40;
        bytes[8] = (bytes[8] & 0x3f) | 0x80;
        bytes
    }

    #[test]
    fn record_id_derivation_matches_subkey_separated_hmac_vector() {
        let ark = crypto::AccountRootKey::from_bytes([0x11; 32]);
        let record_id =
            derive_account_record_id(&ark, b"chat-message/018f2f89-8d5a-7bd2-a459-5d540a8f90ab")
                .expect("规范实体键应可派生记录 ID");

        assert_eq!(
            record_id,
            [
                0x8c, 0x3f, 0x2a, 0x00, 0xe1, 0xe4, 0x44, 0xaa, 0xb4, 0xad, 0x06, 0xfa, 0x57, 0xec,
                0x38, 0xef,
            ]
        );
        assert_eq!(
            derive_account_record_id(&ark, &[]),
            Err(KelivoStatus::InvalidArgument)
        );
        assert_eq!(
            derive_account_record_id(&ark, &[0_u8; RECORD_ENTITY_KEY_MAX_LENGTH + 1]),
            Err(KelivoStatus::InputTooLarge)
        );
    }

    fn register_bound_pending_pairing(created_at: Instant, wall_now_ms: u64) -> u64 {
        let mut rng = protocol::system_rng().expect("测试随机源应可用");
        let identity = crypto::DeviceIdentity::generate(&mut rng).expect("测试设备身份应可生成");
        let target_device_id = crypto::DeviceId::new(uuid_v4(1)).expect("目标设备 UUID 应有效");
        let (pending, _) = create_pending_pairing_at(&identity, target_device_id, 1, created_at)
            .expect("pending 配对应可创建");
        let pairing_id = pending.pairing_id;
        let target_public_keys = pending.target_public_keys;
        let handle = register_pending_pairing(pending).expect("pending 配对应可注册");
        bind_pending_pairing_at(
            handle,
            PairingBindInput {
                protocol_version: PAIRING_PROTOCOL_VERSION,
                pairing_id,
                user_id: crypto::UserId::new(uuid_v4(2)).expect("用户 UUID 应有效"),
                target_device_id,
                target_key_version: 1,
                target_public_keys,
                expires_at_ms: wall_now_ms + PAIRING_LIFETIME_MILLISECONDS,
                challenge: crypto::DeviceProofChallenge::from_bytes([3; 32]),
            },
            wall_now_ms,
            created_at,
        )
        .expect("创建响应应可绑定");

        handle
    }

    #[test]
    fn pending_pairing_wall_clock_expiry_boundary_is_closed() {
        let created_at = Instant::now();
        let wall_now_ms = 1_800_000_000_000;
        let handle = register_bound_pending_pairing(created_at, wall_now_ms);

        assert!(matches!(
            claim_pending_pairing_at(
                handle,
                wall_now_ms + PAIRING_LIFETIME_MILLISECONDS,
                created_at,
            ),
            Err(KelivoStatus::PairingExpired)
        ));
        assert_eq!(
            close_pending_pairing(handle),
            Err(KelivoStatus::InvalidPendingPairingHandle)
        );
    }

    #[test]
    fn pending_pairing_monotonic_deadline_boundary_is_closed() {
        let created_at = Instant::now();
        let wall_now_ms = 1_800_000_000_000;
        let handle = register_bound_pending_pairing(created_at, wall_now_ms);

        let deadline = created_at
            .checked_add(PAIRING_LIFETIME)
            .expect("测试单调时钟应可前移");
        assert!(matches!(
            claim_pending_pairing_at(handle, wall_now_ms, deadline),
            Err(KelivoStatus::PairingExpired)
        ));
        assert_eq!(
            close_pending_pairing(handle),
            Err(KelivoStatus::InvalidPendingPairingHandle)
        );
    }
}
