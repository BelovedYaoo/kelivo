use chacha20poly1305::{
    XChaCha20Poly1305, XNonce,
    aead::{Aead, KeyInit, Payload},
};
use hkdf::Hkdf;
use rand::{CryptoRng, RngCore};
use sha2_device::Sha256;
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use crate::device_crypto::{AccountRootKey, UserId};

const UUID_LENGTH: usize = 16;
const DATA_KEY_LENGTH: usize = 32;
const NONCE_LENGTH: usize = 24;
const TAG_LENGTH: usize = 16;
const FORMAT_VERSION: u16 = 1;
const CIPHER_SUITE: u16 = 1;
const WRAPPED_MAGIC: [u8; 4] = *b"KAWK";
const CHUNK_MAGIC: [u8; 4] = *b"KACH";
const WRAP_AAD_DOMAIN: &[u8] = b"kelivo.attachment.wrap.aad.v1\0";
const WRAP_KEY_INFO: &[u8] = b"kelivo.attachment.wrap.key.v1\0";
const CHUNK_AAD_DOMAIN: &[u8] = b"kelivo.attachment.chunk.aad.v1\0";
const CHUNK_KEY_INFO: &[u8] = b"kelivo.attachment.chunk.key.v1\0";
const WRAPPED_CONTEXT_LENGTH: usize = 4 + 2 + 2 + UUID_LENGTH + UUID_LENGTH + 4;
const WRAPPED_NONCE_OFFSET: usize = WRAPPED_CONTEXT_LENGTH;
const WRAPPED_CIPHERTEXT_OFFSET: usize = WRAPPED_NONCE_OFFSET + NONCE_LENGTH;
const CHUNK_CONTEXT_LENGTH: usize =
    4 + 2 + 2 + UUID_LENGTH + UUID_LENGTH + UUID_LENGTH + 4 + 4 + 4 + 8 + 4;
const CHUNK_NONCE_OFFSET: usize = CHUNK_CONTEXT_LENGTH;
const CHUNK_CIPHERTEXT_OFFSET: usize = CHUNK_NONCE_OFFSET + NONCE_LENGTH;

pub const ATTACHMENT_ID_LENGTH: usize = UUID_LENGTH;
pub const WRAPPED_ATTACHMENT_KEY_LENGTH: usize =
    WRAPPED_CIPHERTEXT_OFFSET + DATA_KEY_LENGTH + TAG_LENGTH;
pub const MAX_ATTACHMENT_CHUNK_ENVELOPE_SIZE: usize = 4 * 1024 * 1024;
pub const ATTACHMENT_CHUNK_ENVELOPE_OVERHEAD: usize = CHUNK_CIPHERTEXT_OFFSET + TAG_LENGTH;
pub const ATTACHMENT_CHUNK_PLAINTEXT_SIZE: usize =
    MAX_ATTACHMENT_CHUNK_ENVELOPE_SIZE - ATTACHMENT_CHUNK_ENVELOPE_OVERHEAD;
pub const MAX_ATTACHMENT_CHUNK_COUNT: u32 = 1000;
pub const MAX_ATTACHMENT_TOTAL_PLAINTEXT_BYTES: u64 =
    ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u64 * MAX_ATTACHMENT_CHUNK_COUNT as u64;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AttachmentCryptoError {
    AuthenticationFailed,
    ContextMismatch,
    CryptoFailed,
    InputTooLarge,
    InvalidChunkGeometry,
    InvalidEnvelope,
    InvalidEpoch,
    InvalidUuidV4,
    RandomnessUnavailable,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AttachmentId([u8; ATTACHMENT_ID_LENGTH]);

impl AttachmentId {
    pub fn generate<R>(rng: &mut R) -> Result<Self, AttachmentCryptoError>
    where
        R: CryptoRng + RngCore,
    {
        let mut bytes = [0_u8; ATTACHMENT_ID_LENGTH];
        rng.try_fill_bytes(&mut bytes)
            .map_err(|_| AttachmentCryptoError::RandomnessUnavailable)?;
        bytes[6] = (bytes[6] & 0x0f) | 0x40;
        bytes[8] = (bytes[8] & 0x3f) | 0x80;
        Ok(Self(bytes))
    }

    pub fn new(bytes: [u8; ATTACHMENT_ID_LENGTH]) -> Result<Self, AttachmentCryptoError> {
        if !is_uuid_v4(&bytes) {
            return Err(AttachmentCryptoError::InvalidUuidV4);
        }
        Ok(Self(bytes))
    }

    pub const fn as_bytes(&self) -> &[u8; ATTACHMENT_ID_LENGTH] {
        &self.0
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AttachmentUploadId([u8; ATTACHMENT_ID_LENGTH]);

impl AttachmentUploadId {
    pub fn new(bytes: [u8; ATTACHMENT_ID_LENGTH]) -> Result<Self, AttachmentCryptoError> {
        if !is_uuid_v4(&bytes) {
            return Err(AttachmentCryptoError::InvalidUuidV4);
        }
        Ok(Self(bytes))
    }

    pub const fn as_bytes(&self) -> &[u8; ATTACHMENT_ID_LENGTH] {
        &self.0
    }
}

pub struct AttachmentDataKey([u8; DATA_KEY_LENGTH]);

impl AttachmentDataKey {
    pub fn generate<R>(rng: &mut R) -> Result<Self, AttachmentCryptoError>
    where
        R: CryptoRng + RngCore,
    {
        let mut bytes = Zeroizing::new([0_u8; DATA_KEY_LENGTH]);
        rng.try_fill_bytes(bytes.as_mut_slice())
            .map_err(|_| AttachmentCryptoError::RandomnessUnavailable)?;
        Ok(Self(*bytes))
    }

    fn from_bytes(bytes: [u8; DATA_KEY_LENGTH]) -> Self {
        Self(bytes)
    }

    fn as_bytes(&self) -> &[u8; DATA_KEY_LENGTH] {
        &self.0
    }
}

impl Zeroize for AttachmentDataKey {
    fn zeroize(&mut self) {
        self.0.zeroize();
    }
}

impl ZeroizeOnDrop for AttachmentDataKey {}

impl Drop for AttachmentDataKey {
    fn drop(&mut self) {
        self.zeroize();
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AttachmentContext {
    pub user_id: UserId,
    pub attachment_id: AttachmentId,
    pub key_epoch: u32,
}

impl AttachmentContext {
    pub fn new(
        user_id: UserId,
        attachment_id: AttachmentId,
        key_epoch: u32,
    ) -> Result<Self, AttachmentCryptoError> {
        if key_epoch == 0 {
            return Err(AttachmentCryptoError::InvalidEpoch);
        }
        Ok(Self {
            user_id,
            attachment_id,
            key_epoch,
        })
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AttachmentChunkContext {
    pub attachment: AttachmentContext,
    pub upload_id: AttachmentUploadId,
    pub chunk_index: u32,
    pub chunk_count: u32,
    pub total_plaintext_bytes: u64,
    pub plaintext_length: u32,
}

impl AttachmentChunkContext {
    pub fn new(
        attachment: AttachmentContext,
        upload_id: AttachmentUploadId,
        chunk_index: u32,
        chunk_count: u32,
        total_plaintext_bytes: u64,
        plaintext_length: u32,
    ) -> Result<Self, AttachmentCryptoError> {
        validate_chunk_geometry(
            chunk_index,
            chunk_count,
            total_plaintext_bytes,
            plaintext_length,
        )?;
        Ok(Self {
            attachment,
            upload_id,
            chunk_index,
            chunk_count,
            total_plaintext_bytes,
            plaintext_length,
        })
    }
}

pub fn wrap_attachment_data_key<R>(
    rng: &mut R,
    ark: &AccountRootKey,
    key: &AttachmentDataKey,
    context: AttachmentContext,
) -> Result<[u8; WRAPPED_ATTACHMENT_KEY_LENGTH], AttachmentCryptoError>
where
    R: CryptoRng + RngCore,
{
    let mut envelope = [0_u8; WRAPPED_ATTACHMENT_KEY_LENGTH];
    write_wrapped_context(&mut envelope[..WRAPPED_CONTEXT_LENGTH], context);
    rng.try_fill_bytes(&mut envelope[WRAPPED_NONCE_OFFSET..WRAPPED_CIPHERTEXT_OFFSET])
        .map_err(|_| AttachmentCryptoError::RandomnessUnavailable)?;

    let wrapping_key = derive_wrapping_key(ark, context)?;
    let cipher = XChaCha20Poly1305::new_from_slice(wrapping_key.as_slice())
        .map_err(|_| AttachmentCryptoError::CryptoFailed)?;
    let nonce = XNonce::from(copy_array(
        &envelope[WRAPPED_NONCE_OFFSET..WRAPPED_CIPHERTEXT_OFFSET],
    ));
    let aad = build_aad(WRAP_AAD_DOMAIN, &envelope[..WRAPPED_CONTEXT_LENGTH])?;
    let ciphertext = cipher
        .encrypt(
            &nonce,
            Payload {
                msg: key.as_bytes(),
                aad: &aad,
            },
        )
        .map_err(|_| AttachmentCryptoError::CryptoFailed)?;
    debug_assert_eq!(ciphertext.len(), DATA_KEY_LENGTH + TAG_LENGTH);
    envelope[WRAPPED_CIPHERTEXT_OFFSET..].copy_from_slice(&ciphertext);
    Ok(envelope)
}

pub fn unwrap_attachment_data_key(
    ark: &AccountRootKey,
    expected: AttachmentContext,
    envelope: &[u8],
) -> Result<AttachmentDataKey, AttachmentCryptoError> {
    if envelope.len() != WRAPPED_ATTACHMENT_KEY_LENGTH {
        return Err(AttachmentCryptoError::InvalidEnvelope);
    }
    let actual = parse_wrapped_context(&envelope[..WRAPPED_CONTEXT_LENGTH])?;
    if actual != expected {
        return Err(AttachmentCryptoError::ContextMismatch);
    }

    let wrapping_key = derive_wrapping_key(ark, expected)?;
    let cipher = XChaCha20Poly1305::new_from_slice(wrapping_key.as_slice())
        .map_err(|_| AttachmentCryptoError::CryptoFailed)?;
    let nonce = XNonce::from(copy_array(
        &envelope[WRAPPED_NONCE_OFFSET..WRAPPED_CIPHERTEXT_OFFSET],
    ));
    let aad = build_aad(WRAP_AAD_DOMAIN, &envelope[..WRAPPED_CONTEXT_LENGTH])?;
    let plaintext = Zeroizing::new(
        cipher
            .decrypt(
                &nonce,
                Payload {
                    msg: &envelope[WRAPPED_CIPHERTEXT_OFFSET..],
                    aad: &aad,
                },
            )
            .map_err(|_| AttachmentCryptoError::AuthenticationFailed)?,
    );
    if plaintext.len() != DATA_KEY_LENGTH {
        return Err(AttachmentCryptoError::InvalidEnvelope);
    }
    let mut bytes = Zeroizing::new([0_u8; DATA_KEY_LENGTH]);
    bytes.copy_from_slice(plaintext.as_slice());
    Ok(AttachmentDataKey::from_bytes(*bytes))
}

pub fn attachment_chunk_envelope_size(
    context: AttachmentChunkContext,
) -> Result<usize, AttachmentCryptoError> {
    validate_chunk_context(context)?;
    CHUNK_CIPHERTEXT_OFFSET
        .checked_add(context.plaintext_length as usize)
        .and_then(|size| size.checked_add(TAG_LENGTH))
        .ok_or(AttachmentCryptoError::InputTooLarge)
}

pub fn opened_attachment_chunk_size(
    expected: AttachmentChunkContext,
    envelope: &[u8],
) -> Result<usize, AttachmentCryptoError> {
    validate_chunk_context(expected)?;
    let actual = parse_chunk_context(envelope)?;
    if actual != expected {
        return Err(AttachmentCryptoError::ContextMismatch);
    }
    Ok(expected.plaintext_length as usize)
}

pub fn seal_attachment_chunk<R>(
    rng: &mut R,
    key: &AttachmentDataKey,
    context: AttachmentChunkContext,
    plaintext: &[u8],
) -> Result<Vec<u8>, AttachmentCryptoError>
where
    R: CryptoRng + RngCore,
{
    validate_chunk_context(context)?;
    if plaintext.len() != context.plaintext_length as usize {
        return Err(AttachmentCryptoError::InvalidChunkGeometry);
    }
    let expected_size = attachment_chunk_envelope_size(context)?;
    let mut envelope = vec![0_u8; expected_size];
    write_chunk_context(&mut envelope[..CHUNK_CONTEXT_LENGTH], context);
    rng.try_fill_bytes(&mut envelope[CHUNK_NONCE_OFFSET..CHUNK_CIPHERTEXT_OFFSET])
        .map_err(|_| AttachmentCryptoError::RandomnessUnavailable)?;

    let chunk_key = derive_chunk_key(key, context)?;
    let cipher = XChaCha20Poly1305::new_from_slice(chunk_key.as_slice())
        .map_err(|_| AttachmentCryptoError::CryptoFailed)?;
    let nonce = XNonce::from(copy_array(
        &envelope[CHUNK_NONCE_OFFSET..CHUNK_CIPHERTEXT_OFFSET],
    ));
    let aad = build_aad(CHUNK_AAD_DOMAIN, &envelope[..CHUNK_CONTEXT_LENGTH])?;
    let ciphertext = cipher
        .encrypt(
            &nonce,
            Payload {
                msg: plaintext,
                aad: &aad,
            },
        )
        .map_err(|_| AttachmentCryptoError::CryptoFailed)?;
    envelope[CHUNK_CIPHERTEXT_OFFSET..].copy_from_slice(&ciphertext);
    Ok(envelope)
}

pub fn open_attachment_chunk(
    key: &AttachmentDataKey,
    expected: AttachmentChunkContext,
    envelope: &[u8],
) -> Result<Zeroizing<Vec<u8>>, AttachmentCryptoError> {
    opened_attachment_chunk_size(expected, envelope)?;
    let chunk_key = derive_chunk_key(key, expected)?;
    let cipher = XChaCha20Poly1305::new_from_slice(chunk_key.as_slice())
        .map_err(|_| AttachmentCryptoError::CryptoFailed)?;
    let nonce = XNonce::from(copy_array(
        &envelope[CHUNK_NONCE_OFFSET..CHUNK_CIPHERTEXT_OFFSET],
    ));
    let aad = build_aad(CHUNK_AAD_DOMAIN, &envelope[..CHUNK_CONTEXT_LENGTH])?;
    cipher
        .decrypt(
            &nonce,
            Payload {
                msg: &envelope[CHUNK_CIPHERTEXT_OFFSET..],
                aad: &aad,
            },
        )
        .map(Zeroizing::new)
        .map_err(|_| AttachmentCryptoError::AuthenticationFailed)
}

fn derive_wrapping_key(
    ark: &AccountRootKey,
    context: AttachmentContext,
) -> Result<Zeroizing<[u8; DATA_KEY_LENGTH]>, AttachmentCryptoError> {
    let context_bytes = encode_context_binding(context);
    let mut key = Zeroizing::new([0_u8; DATA_KEY_LENGTH]);
    Hkdf::<Sha256>::new(Some(&context_bytes), ark.as_bytes())
        .expand(WRAP_KEY_INFO, key.as_mut_slice())
        .map_err(|_| AttachmentCryptoError::CryptoFailed)?;
    Ok(key)
}

fn derive_chunk_key(
    data_key: &AttachmentDataKey,
    context: AttachmentChunkContext,
) -> Result<Zeroizing<[u8; DATA_KEY_LENGTH]>, AttachmentCryptoError> {
    let mut salt = Zeroizing::new(Vec::with_capacity(60));
    salt.extend_from_slice(&encode_context_binding(context.attachment));
    salt.extend_from_slice(context.upload_id.as_bytes());
    salt.extend_from_slice(&context.chunk_index.to_be_bytes());
    let mut key = Zeroizing::new([0_u8; DATA_KEY_LENGTH]);
    Hkdf::<Sha256>::new(Some(salt.as_slice()), data_key.as_bytes())
        .expand(CHUNK_KEY_INFO, key.as_mut_slice())
        .map_err(|_| AttachmentCryptoError::CryptoFailed)?;
    Ok(key)
}

fn encode_context_binding(context: AttachmentContext) -> [u8; 36] {
    let mut encoded = [0_u8; 36];
    encoded[..16].copy_from_slice(context.user_id.as_bytes());
    encoded[16..32].copy_from_slice(context.attachment_id.as_bytes());
    encoded[32..].copy_from_slice(&context.key_epoch.to_be_bytes());
    encoded
}

fn write_wrapped_context(output: &mut [u8], context: AttachmentContext) {
    debug_assert_eq!(output.len(), WRAPPED_CONTEXT_LENGTH);
    output[..4].copy_from_slice(&WRAPPED_MAGIC);
    output[4..6].copy_from_slice(&FORMAT_VERSION.to_be_bytes());
    output[6..8].copy_from_slice(&CIPHER_SUITE.to_be_bytes());
    output[8..24].copy_from_slice(context.user_id.as_bytes());
    output[24..40].copy_from_slice(context.attachment_id.as_bytes());
    output[40..44].copy_from_slice(&context.key_epoch.to_be_bytes());
}

fn parse_wrapped_context(input: &[u8]) -> Result<AttachmentContext, AttachmentCryptoError> {
    if input.len() != WRAPPED_CONTEXT_LENGTH
        || input[..4] != WRAPPED_MAGIC
        || u16::from_be_bytes(copy_array(&input[4..6])) != FORMAT_VERSION
        || u16::from_be_bytes(copy_array(&input[6..8])) != CIPHER_SUITE
    {
        return Err(AttachmentCryptoError::InvalidEnvelope);
    }
    parse_attachment_context(&input[8..24], &input[24..40], &input[40..44])
        .map_err(|_| AttachmentCryptoError::InvalidEnvelope)
}

fn write_chunk_context(output: &mut [u8], context: AttachmentChunkContext) {
    debug_assert_eq!(output.len(), CHUNK_CONTEXT_LENGTH);
    output[..4].copy_from_slice(&CHUNK_MAGIC);
    output[4..6].copy_from_slice(&FORMAT_VERSION.to_be_bytes());
    output[6..8].copy_from_slice(&CIPHER_SUITE.to_be_bytes());
    output[8..24].copy_from_slice(context.attachment.user_id.as_bytes());
    output[24..40].copy_from_slice(context.attachment.attachment_id.as_bytes());
    output[40..56].copy_from_slice(context.upload_id.as_bytes());
    output[56..60].copy_from_slice(&context.attachment.key_epoch.to_be_bytes());
    output[60..64].copy_from_slice(&context.chunk_index.to_be_bytes());
    output[64..68].copy_from_slice(&context.chunk_count.to_be_bytes());
    output[68..76].copy_from_slice(&context.total_plaintext_bytes.to_be_bytes());
    output[76..80].copy_from_slice(&context.plaintext_length.to_be_bytes());
}

fn parse_chunk_context(input: &[u8]) -> Result<AttachmentChunkContext, AttachmentCryptoError> {
    if input.len() < CHUNK_CIPHERTEXT_OFFSET + TAG_LENGTH
        || input.len() > MAX_ATTACHMENT_CHUNK_ENVELOPE_SIZE
        || input[..4] != CHUNK_MAGIC
        || u16::from_be_bytes(copy_array(&input[4..6])) != FORMAT_VERSION
        || u16::from_be_bytes(copy_array(&input[6..8])) != CIPHER_SUITE
    {
        return Err(AttachmentCryptoError::InvalidEnvelope);
    }
    let attachment = parse_attachment_context(&input[8..24], &input[24..40], &input[56..60])
        .map_err(|_| AttachmentCryptoError::InvalidEnvelope)?;
    let upload_id = AttachmentUploadId::new(copy_array(&input[40..56]))
        .map_err(|_| AttachmentCryptoError::InvalidEnvelope)?;
    let context = AttachmentChunkContext::new(
        attachment,
        upload_id,
        u32::from_be_bytes(copy_array(&input[60..64])),
        u32::from_be_bytes(copy_array(&input[64..68])),
        u64::from_be_bytes(copy_array(&input[68..76])),
        u32::from_be_bytes(copy_array(&input[76..80])),
    )
    .map_err(|_| AttachmentCryptoError::InvalidEnvelope)?;
    if input.len() != attachment_chunk_envelope_size(context)? {
        return Err(AttachmentCryptoError::InvalidEnvelope);
    }
    Ok(context)
}

fn parse_attachment_context(
    user_id: &[u8],
    attachment_id: &[u8],
    epoch: &[u8],
) -> Result<AttachmentContext, AttachmentCryptoError> {
    AttachmentContext::new(
        UserId::new(copy_array(user_id)).map_err(|_| AttachmentCryptoError::InvalidUuidV4)?,
        AttachmentId::new(copy_array(attachment_id))?,
        u32::from_be_bytes(copy_array(epoch)),
    )
}

fn validate_chunk_context(context: AttachmentChunkContext) -> Result<(), AttachmentCryptoError> {
    if context.attachment.key_epoch == 0 {
        return Err(AttachmentCryptoError::InvalidEpoch);
    }
    validate_chunk_geometry(
        context.chunk_index,
        context.chunk_count,
        context.total_plaintext_bytes,
        context.plaintext_length,
    )
}

fn validate_chunk_geometry(
    chunk_index: u32,
    chunk_count: u32,
    total_plaintext_bytes: u64,
    plaintext_length: u32,
) -> Result<(), AttachmentCryptoError> {
    if total_plaintext_bytes > MAX_ATTACHMENT_TOTAL_PLAINTEXT_BYTES {
        return Err(AttachmentCryptoError::InputTooLarge);
    }
    let expected_count = required_chunk_count(total_plaintext_bytes)?;
    if chunk_count > MAX_ATTACHMENT_CHUNK_COUNT
        || chunk_count != expected_count
        || chunk_index >= chunk_count
    {
        return Err(AttachmentCryptoError::InvalidChunkGeometry);
    }
    let expected_length = expected_chunk_plaintext_length(total_plaintext_bytes, chunk_index)?;
    if plaintext_length != expected_length {
        return Err(AttachmentCryptoError::InvalidChunkGeometry);
    }
    Ok(())
}

fn required_chunk_count(total_plaintext_bytes: u64) -> Result<u32, AttachmentCryptoError> {
    if total_plaintext_bytes == 0 {
        return Ok(1);
    }
    let chunk_size = ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u64;
    let count = total_plaintext_bytes
        .checked_add(chunk_size - 1)
        .ok_or(AttachmentCryptoError::InputTooLarge)?
        / chunk_size;
    u32::try_from(count).map_err(|_| AttachmentCryptoError::InputTooLarge)
}

fn expected_chunk_plaintext_length(
    total_plaintext_bytes: u64,
    chunk_index: u32,
) -> Result<u32, AttachmentCryptoError> {
    if total_plaintext_bytes == 0 {
        return Ok(0);
    }
    let offset = u64::from(chunk_index)
        .checked_mul(ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u64)
        .ok_or(AttachmentCryptoError::InputTooLarge)?;
    let remaining = total_plaintext_bytes
        .checked_sub(offset)
        .ok_or(AttachmentCryptoError::InvalidChunkGeometry)?;
    u32::try_from(remaining.min(ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u64))
        .map_err(|_| AttachmentCryptoError::InputTooLarge)
}

fn build_aad(domain: &[u8], context: &[u8]) -> Result<Vec<u8>, AttachmentCryptoError> {
    let mut aad = Vec::with_capacity(domain.len() + 8 + context.len());
    aad.extend_from_slice(domain);
    aad.extend_from_slice(
        &u64::try_from(context.len())
            .map_err(|_| AttachmentCryptoError::InputTooLarge)?
            .to_be_bytes(),
    );
    aad.extend_from_slice(context);
    Ok(aad)
}

fn is_uuid_v4(value: &[u8; UUID_LENGTH]) -> bool {
    value[6] & 0xf0 == 0x40 && value[8] & 0xc0 == 0x80
}

fn copy_array<const N: usize>(input: &[u8]) -> [u8; N] {
    input.try_into().expect("固定线格式切片长度必须已验证")
}

#[cfg(test)]
mod tests {
    use super::*;
    use rand::{CryptoRng, Error as RngError, RngCore};

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

        fn try_fill_bytes(&mut self, destination: &mut [u8]) -> Result<(), RngError> {
            self.fill_bytes(destination);
            Ok(())
        }
    }

    impl CryptoRng for TestRng {}

    fn uuid(seed: u8) -> [u8; 16] {
        let mut value = [seed; 16];
        value[6] = (value[6] & 0x0f) | 0x40;
        value[8] = (value[8] & 0x3f) | 0x80;
        value
    }

    fn context(seed: u8, epoch: u32) -> AttachmentContext {
        AttachmentContext::new(
            UserId::new(uuid(seed)).expect("用户 UUID 有效"),
            AttachmentId::new(uuid(seed.wrapping_add(1))).expect("附件 UUID 有效"),
            epoch,
        )
        .expect("附件上下文有效")
    }

    fn upload(seed: u8) -> AttachmentUploadId {
        AttachmentUploadId::new(uuid(seed)).expect("上传 UUID 有效")
    }

    #[test]
    fn wrapped_key_and_chunk_round_trip_with_strict_context() {
        let ark = AccountRootKey::from_bytes([0x11; 32]);
        let key = AttachmentDataKey::generate(&mut TestRng(1)).expect("数据密钥应生成");
        let attachment = context(0x21, 7);
        let wrapped = wrap_attachment_data_key(&mut TestRng(2), &ark, &key, attachment)
            .expect("数据密钥应包装");
        let reopened =
            unwrap_attachment_data_key(&ark, attachment, &wrapped).expect("数据密钥应解包");
        let other_ark = AccountRootKey::from_bytes([0x12; 32]);
        assert!(matches!(
            unwrap_attachment_data_key(&other_ark, attachment, &wrapped),
            Err(AttachmentCryptoError::AuthenticationFailed)
        ));
        assert!(matches!(
            unwrap_attachment_data_key(&ark, context(0x22, 7), &wrapped),
            Err(AttachmentCryptoError::ContextMismatch)
        ));
        let mut tampered_wrapped = wrapped;
        *tampered_wrapped.last_mut().expect("包装信封非空") ^= 1;
        assert!(matches!(
            unwrap_attachment_data_key(&ark, attachment, &tampered_wrapped),
            Err(AttachmentCryptoError::AuthenticationFailed)
        ));
        assert!(matches!(
            unwrap_attachment_data_key(
                &ark,
                attachment,
                &wrapped[..WRAPPED_ATTACHMENT_KEY_LENGTH - 1],
            ),
            Err(AttachmentCryptoError::InvalidEnvelope)
        ));
        let plaintext = b"attachment chunk";
        let chunk_context = AttachmentChunkContext::new(
            attachment,
            upload(0x71),
            0,
            1,
            plaintext.len() as u64,
            plaintext.len() as u32,
        )
        .expect("分块上下文有效");
        let envelope = seal_attachment_chunk(&mut TestRng(3), &key, chunk_context, plaintext)
            .expect("分块应加密");

        assert_eq!(
            open_attachment_chunk(&reopened, chunk_context, &envelope)
                .expect("分块应解密")
                .as_slice(),
            plaintext
        );
    }

    #[test]
    fn chunk_rejects_tampering_replacement_reordering_and_context_changes() {
        let key = AttachmentDataKey::generate(&mut TestRng(5)).expect("数据密钥应生成");
        let other_key = AttachmentDataKey::generate(&mut TestRng(6)).expect("另一密钥应生成");
        let attachment = context(0x31, 9);
        let total = ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u64 + 1;
        let first_context = AttachmentChunkContext::new(
            attachment,
            upload(0x72),
            0,
            2,
            total,
            ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u32,
        )
        .expect("首块上下文有效");
        let plaintext = vec![0x7a; ATTACHMENT_CHUNK_PLAINTEXT_SIZE];
        let envelope = seal_attachment_chunk(&mut TestRng(7), &key, first_context, &plaintext)
            .expect("首块应加密");

        let mut tampered = envelope.clone();
        *tampered.last_mut().expect("信封非空") ^= 1;
        assert!(matches!(
            open_attachment_chunk(&key, first_context, &tampered),
            Err(AttachmentCryptoError::AuthenticationFailed)
        ));
        assert!(matches!(
            open_attachment_chunk(&other_key, first_context, &envelope),
            Err(AttachmentCryptoError::AuthenticationFailed)
        ));

        let second_context =
            AttachmentChunkContext::new(attachment, first_context.upload_id, 1, 2, total, 1)
                .expect("末块上下文有效");
        assert!(matches!(
            open_attachment_chunk(&key, second_context, &envelope),
            Err(AttachmentCryptoError::ContextMismatch)
        ));

        let other_attachment = AttachmentChunkContext::new(
            context(0x32, 9),
            first_context.upload_id,
            0,
            2,
            total,
            ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u32,
        )
        .expect("另一附件上下文有效");
        assert!(matches!(
            open_attachment_chunk(&key, other_attachment, &envelope),
            Err(AttachmentCryptoError::ContextMismatch)
        ));
        let other_epoch = AttachmentChunkContext::new(
            context(0x31, 10),
            first_context.upload_id,
            0,
            2,
            total,
            ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u32,
        )
        .expect("另一 epoch 上下文有效");
        assert!(matches!(
            open_attachment_chunk(&key, other_epoch, &envelope),
            Err(AttachmentCryptoError::ContextMismatch)
        ));
        let other_upload = AttachmentChunkContext::new(
            attachment,
            upload(0x73),
            0,
            2,
            total,
            ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u32,
        )
        .expect("另一上传上下文有效");
        assert!(matches!(
            open_attachment_chunk(&key, other_upload, &envelope),
            Err(AttachmentCryptoError::ContextMismatch)
        ));
    }

    #[test]
    fn canonical_chunk_geometry_enforces_empty_maximum_and_overflow_boundaries() {
        let attachment = context(0x41, u32::MAX);
        let upload = upload(0x74);
        assert!(AttachmentChunkContext::new(attachment, upload, 0, 1, 0, 0).is_ok());
        assert!(
            AttachmentChunkContext::new(
                attachment,
                upload,
                0,
                1,
                ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u64,
                ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u32,
            )
            .is_ok()
        );
        let maximum = AttachmentChunkContext::new(
            attachment,
            upload,
            MAX_ATTACHMENT_CHUNK_COUNT - 1,
            MAX_ATTACHMENT_CHUNK_COUNT,
            MAX_ATTACHMENT_TOTAL_PLAINTEXT_BYTES,
            ATTACHMENT_CHUNK_PLAINTEXT_SIZE as u32,
        )
        .expect("最大规范附件末块上下文有效");
        assert_eq!(
            attachment_chunk_envelope_size(maximum).expect("最大块信封长度有效"),
            MAX_ATTACHMENT_CHUNK_ENVELOPE_SIZE
        );
        assert!(matches!(
            AttachmentChunkContext::new(attachment, upload, 0, 2, 1, 1),
            Err(AttachmentCryptoError::InvalidChunkGeometry)
        ));
        assert!(matches!(
            AttachmentChunkContext::new(
                attachment,
                upload,
                0,
                1,
                MAX_ATTACHMENT_TOTAL_PLAINTEXT_BYTES + 1,
                0,
            ),
            Err(AttachmentCryptoError::InputTooLarge)
        ));
        assert!(matches!(
            AttachmentContext::new(
                UserId::new(uuid(0x42)).expect("用户 UUID 有效"),
                AttachmentId::new(uuid(0x43)).expect("附件 UUID 有效"),
                0,
            ),
            Err(AttachmentCryptoError::InvalidEpoch)
        ));
        assert!(matches!(
            AttachmentId::new([0; 16]),
            Err(AttachmentCryptoError::InvalidUuidV4)
        ));
        assert!(matches!(
            AttachmentUploadId::new([0; 16]),
            Err(AttachmentCryptoError::InvalidUuidV4)
        ));
    }
}
