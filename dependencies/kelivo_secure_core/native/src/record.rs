use chacha20poly1305::{
    XChaCha20Poly1305, XNonce,
    aead::{Aead, KeyInit, Payload},
};
use core::mem::size_of;
use hkdf::Hkdf;
use sha2::Sha256;
use zeroize::Zeroizing;

const ENVELOPE_VERSION: u64 = 1;
const ALGORITHM_SUITE: u64 = 1;
const KEY_INFO: &[u8] = b"kelivo.record.key.v1";
const AAD_DOMAIN: &[u8] = b"kelivo.record.aad.v1";
const TAG_SIZE: usize = 16;

pub(super) const RECORD_ID_SIZE: usize = 16;
pub(super) const RECORD_NONCE_SIZE: usize = 24;
pub(super) const MAX_EXTERNAL_AAD_SIZE: usize = 64 * 1024;
// 附件走独立的分块加密路径；记录上限只覆盖聊天与配置，避免不受控的大块分配。
pub(super) const MAX_PLAINTEXT_SIZE: usize = 16 * 1024 * 1024;
pub(super) const MAX_ENVELOPE_SIZE: usize = MAX_PLAINTEXT_SIZE + 80;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(super) enum RecordError {
    AuthenticationFailed,
    ContextMismatch,
    Crypto,
    InputTooLarge,
    InvalidInput,
    InvalidEnvelope,
}

pub(super) fn envelope_size(epoch: u64, plaintext_size: usize) -> Result<usize, RecordError> {
    validate_plaintext(epoch, plaintext_size)?;
    let ciphertext_size = plaintext_size
        .checked_add(TAG_SIZE)
        .ok_or(RecordError::InputTooLarge)?;
    1_usize
        .checked_add(unsigned_size(ENVELOPE_VERSION))
        .and_then(|size| size.checked_add(unsigned_size(ALGORITHM_SUITE)))
        .and_then(|size| size.checked_add(unsigned_size(epoch)))
        .and_then(|size| size.checked_add(bytes_size(RECORD_ID_SIZE)))
        .and_then(|size| size.checked_add(bytes_size(RECORD_NONCE_SIZE)))
        .and_then(|size| size.checked_add(bytes_size(ciphertext_size)))
        .ok_or(RecordError::InputTooLarge)
}

pub(super) fn opened_size(
    expected_record_id: &[u8; RECORD_ID_SIZE],
    expected_epoch: u64,
    envelope: &[u8],
) -> Result<usize, RecordError> {
    if expected_epoch == 0 {
        return Err(RecordError::InvalidInput);
    }
    let parsed = parse_envelope(envelope)?;
    if parsed.record_id != expected_record_id || parsed.epoch != expected_epoch {
        return Err(RecordError::ContextMismatch);
    }
    Ok(parsed.ciphertext.len() - TAG_SIZE)
}

pub(super) fn seal_with_nonce(
    master_key: &[u8; 32],
    record_id: &[u8; 16],
    epoch: u64,
    external_aad: &[u8],
    plaintext: &[u8],
    nonce: &[u8; 24],
) -> Result<Vec<u8>, RecordError> {
    validate_inputs(epoch, external_aad.len(), plaintext.len())?;
    let expected_size = envelope_size(epoch, plaintext.len())?;
    let record_key = derive_record_key(master_key, record_id, epoch)?;
    let aad = build_aad(external_aad)?;
    let cipher =
        XChaCha20Poly1305::new_from_slice(&record_key[..]).map_err(|_| RecordError::Crypto)?;
    let nonce = XNonce::from(*nonce);
    let ciphertext = cipher
        .encrypt(
            &nonce,
            Payload {
                msg: plaintext,
                aad: &aad,
            },
        )
        .map_err(|_| RecordError::Crypto)?;

    let mut envelope = Vec::with_capacity(expected_size);
    envelope.push(0x86);
    encode_unsigned(ENVELOPE_VERSION, &mut envelope);
    encode_unsigned(ALGORITHM_SUITE, &mut envelope);
    encode_unsigned(epoch, &mut envelope);
    encode_bytes(record_id, &mut envelope);
    encode_bytes(nonce.as_slice(), &mut envelope);
    encode_bytes(&ciphertext, &mut envelope);
    debug_assert_eq!(envelope.len(), expected_size);
    Ok(envelope)
}

pub(super) fn open(
    master_key: &[u8; 32],
    expected_record_id: &[u8; 16],
    expected_epoch: u64,
    external_aad: &[u8],
    envelope: &[u8],
) -> Result<Zeroizing<Vec<u8>>, RecordError> {
    if external_aad.len() > MAX_EXTERNAL_AAD_SIZE {
        return Err(RecordError::InputTooLarge);
    }
    let parsed = parse_envelope(envelope)?;
    if parsed.record_id != expected_record_id || parsed.epoch != expected_epoch {
        return Err(RecordError::ContextMismatch);
    }

    let record_key = derive_record_key(master_key, expected_record_id, expected_epoch)?;
    let aad = build_aad(external_aad)?;
    let cipher =
        XChaCha20Poly1305::new_from_slice(&record_key[..]).map_err(|_| RecordError::Crypto)?;
    let nonce = XNonce::from(parsed.nonce);
    cipher
        .decrypt(
            &nonce,
            Payload {
                msg: parsed.ciphertext,
                aad: &aad,
            },
        )
        .map(Zeroizing::new)
        .map_err(|_| RecordError::AuthenticationFailed)
}

fn derive_record_key(
    master_key: &[u8; 32],
    record_id: &[u8; 16],
    epoch: u64,
) -> Result<Zeroizing<[u8; 32]>, RecordError> {
    let mut record_key = Zeroizing::new([0_u8; 32]);
    let epoch_bytes = epoch.to_be_bytes();
    Hkdf::<Sha256>::new(Some(record_id), master_key)
        .expand_multi_info(&[KEY_INFO, &epoch_bytes], &mut record_key[..])
        .map_err(|_| RecordError::Crypto)?;
    Ok(record_key)
}

fn build_aad(external_aad: &[u8]) -> Result<Vec<u8>, RecordError> {
    let mut aad = Vec::with_capacity(AAD_DOMAIN.len() + size_of::<u64>() + external_aad.len());
    aad.extend_from_slice(AAD_DOMAIN);
    let length = u64::try_from(external_aad.len()).map_err(|_| RecordError::InputTooLarge)?;
    aad.extend_from_slice(&length.to_be_bytes());
    aad.extend_from_slice(external_aad);
    Ok(aad)
}

struct ParsedEnvelope<'a> {
    epoch: u64,
    record_id: &'a [u8],
    nonce: [u8; 24],
    ciphertext: &'a [u8],
}

fn parse_envelope(envelope: &[u8]) -> Result<ParsedEnvelope<'_>, RecordError> {
    if envelope.len() > envelope_size(u64::MAX, MAX_PLAINTEXT_SIZE)? {
        return Err(RecordError::InputTooLarge);
    }
    let mut position = 0;
    if read_byte(envelope, &mut position)? != 0x86 {
        return Err(RecordError::InvalidEnvelope);
    }
    if decode_unsigned(envelope, &mut position)? != ENVELOPE_VERSION
        || decode_unsigned(envelope, &mut position)? != ALGORITHM_SUITE
    {
        return Err(RecordError::InvalidEnvelope);
    }
    let epoch = decode_unsigned(envelope, &mut position)?;
    if epoch == 0 {
        return Err(RecordError::InvalidEnvelope);
    }
    let record_id = decode_bytes(envelope, &mut position)?;
    if record_id.len() != RECORD_ID_SIZE {
        return Err(RecordError::InvalidEnvelope);
    }
    let nonce_bytes = decode_bytes(envelope, &mut position)?;
    let nonce = <[u8; RECORD_NONCE_SIZE]>::try_from(nonce_bytes)
        .map_err(|_| RecordError::InvalidEnvelope)?;
    let ciphertext = decode_bytes(envelope, &mut position)?;
    if ciphertext.len() < TAG_SIZE
        || ciphertext.len() > MAX_PLAINTEXT_SIZE + TAG_SIZE
        || position != envelope.len()
    {
        return Err(RecordError::InvalidEnvelope);
    }
    Ok(ParsedEnvelope {
        epoch,
        record_id,
        nonce,
        ciphertext,
    })
}

fn validate_inputs(
    epoch: u64,
    external_aad_size: usize,
    plaintext_size: usize,
) -> Result<(), RecordError> {
    validate_plaintext(epoch, plaintext_size)?;
    if external_aad_size > MAX_EXTERNAL_AAD_SIZE {
        return Err(RecordError::InputTooLarge);
    }
    Ok(())
}

fn validate_plaintext(epoch: u64, plaintext_size: usize) -> Result<(), RecordError> {
    if epoch == 0 {
        return Err(RecordError::InvalidInput);
    }
    if plaintext_size > MAX_PLAINTEXT_SIZE {
        return Err(RecordError::InputTooLarge);
    }
    Ok(())
}

const fn unsigned_size(value: u64) -> usize {
    match value {
        0..=23 => 1,
        24..=0xff => 2,
        0x100..=0xffff => 3,
        0x1_0000..=0xffff_ffff => 5,
        _ => 9,
    }
}

const fn bytes_size(length: usize) -> usize {
    let header = match length {
        0..=23 => 1,
        24..=0xff => 2,
        0x100..=0xffff => 3,
        0x1_0000..=0xffff_ffff => 5,
        _ => 9,
    };
    header + length
}

fn decode_unsigned(input: &[u8], position: &mut usize) -> Result<u64, RecordError> {
    let initial = read_byte(input, position)?;
    if initial >> 5 != 0 {
        return Err(RecordError::InvalidEnvelope);
    }
    decode_additional(input, position, initial & 0x1f)
}

fn decode_bytes<'a>(input: &'a [u8], position: &mut usize) -> Result<&'a [u8], RecordError> {
    let initial = read_byte(input, position)?;
    if initial >> 5 != 2 {
        return Err(RecordError::InvalidEnvelope);
    }
    let length = usize::try_from(decode_additional(input, position, initial & 0x1f)?)
        .map_err(|_| RecordError::InvalidEnvelope)?;
    let end = position
        .checked_add(length)
        .ok_or(RecordError::InvalidEnvelope)?;
    let value = input
        .get(*position..end)
        .ok_or(RecordError::InvalidEnvelope)?;
    *position = end;
    Ok(value)
}

fn decode_additional(
    input: &[u8],
    position: &mut usize,
    additional: u8,
) -> Result<u64, RecordError> {
    match additional {
        0..=23 => Ok(u64::from(additional)),
        24 => {
            let value = u64::from(read_byte(input, position)?);
            (value >= 24)
                .then_some(value)
                .ok_or(RecordError::InvalidEnvelope)
        }
        25 => {
            let value = u64::from(u16::from_be_bytes(read_array(input, position)?));
            (value > 0xff)
                .then_some(value)
                .ok_or(RecordError::InvalidEnvelope)
        }
        26 => {
            let value = u64::from(u32::from_be_bytes(read_array(input, position)?));
            (value > 0xffff)
                .then_some(value)
                .ok_or(RecordError::InvalidEnvelope)
        }
        27 => {
            let value = u64::from_be_bytes(read_array(input, position)?);
            (value > 0xffff_ffff)
                .then_some(value)
                .ok_or(RecordError::InvalidEnvelope)
        }
        _ => Err(RecordError::InvalidEnvelope),
    }
}

fn read_byte(input: &[u8], position: &mut usize) -> Result<u8, RecordError> {
    let value = input
        .get(*position)
        .copied()
        .ok_or(RecordError::InvalidEnvelope)?;
    *position += 1;
    Ok(value)
}

fn read_array<const N: usize>(input: &[u8], position: &mut usize) -> Result<[u8; N], RecordError> {
    let end = position
        .checked_add(N)
        .ok_or(RecordError::InvalidEnvelope)?;
    let value = input
        .get(*position..end)
        .ok_or(RecordError::InvalidEnvelope)?;
    *position = end;
    <[u8; N]>::try_from(value).map_err(|_| RecordError::InvalidEnvelope)
}

fn encode_unsigned(value: u64, output: &mut Vec<u8>) {
    match value {
        0..=23 => output.push(value as u8),
        24..=0xff => output.extend_from_slice(&[0x18, value as u8]),
        0x100..=0xffff => {
            output.push(0x19);
            output.extend_from_slice(&(value as u16).to_be_bytes());
        }
        0x1_0000..=0xffff_ffff => {
            output.push(0x1a);
            output.extend_from_slice(&(value as u32).to_be_bytes());
        }
        _ => {
            output.push(0x1b);
            output.extend_from_slice(&value.to_be_bytes());
        }
    }
}

fn encode_bytes(value: &[u8], output: &mut Vec<u8>) {
    encode_major_length(2, value.len(), output);
    output.extend_from_slice(value);
}

fn encode_major_length(major: u8, length: usize, output: &mut Vec<u8>) {
    let prefix = major << 5;
    match length {
        0..=23 => output.push(prefix | length as u8),
        24..=0xff => output.extend_from_slice(&[prefix | 24, length as u8]),
        0x100..=0xffff => {
            output.push(prefix | 25);
            output.extend_from_slice(&(length as u16).to_be_bytes());
        }
        0x1_0000..=0xffff_ffff => {
            output.push(prefix | 26);
            output.extend_from_slice(&(length as u32).to_be_bytes());
        }
        _ => {
            output.push(prefix | 27);
            output.extend_from_slice(&(length as u64).to_be_bytes());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{open, seal_with_nonce};

    const EXPECTED_ENVELOPE: &[u8] = &[
        0x86, 0x01, 0x01, 0x07, 0x50, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19,
        0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x58, 0x18, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6,
        0xa7, 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae, 0xaf, 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5,
        0xb6, 0xb7, 0x58, 0x29, 0x1d, 0xce, 0x11, 0x7c, 0x48, 0x72, 0xf4, 0x85, 0x13, 0x1d, 0xb2,
        0xd0, 0x33, 0x63, 0x5f, 0x17, 0x3e, 0x13, 0x7d, 0x10, 0xb3, 0x0f, 0x96, 0x7f, 0xc0, 0x8d,
        0x70, 0xd5, 0xb3, 0x80, 0x5a, 0x9f, 0x45, 0x81, 0x97, 0x8a, 0x33, 0x65, 0xd1, 0x47, 0xc8,
    ];

    #[test]
    fn record_envelope_v1_matches_independent_vector() {
        let master_key = core::array::from_fn(|index| index as u8);
        let record_id = core::array::from_fn(|index| 0x10 + index as u8);
        let nonce = core::array::from_fn(|index| 0xa0 + index as u8);

        let envelope = seal_with_nonce(
            &master_key,
            &record_id,
            7,
            b"kelivo-test-aad",
            b"Kelivo record envelope v1",
            &nonce,
        )
        .expect("固定向量应成功密封");

        assert_eq!(envelope, EXPECTED_ENVELOPE);
    }

    #[test]
    fn record_envelope_v1_opens_independent_vector() {
        let master_key = core::array::from_fn(|index| index as u8);
        let record_id = core::array::from_fn(|index| 0x10 + index as u8);

        let plaintext = open(
            &master_key,
            &record_id,
            7,
            b"kelivo-test-aad",
            EXPECTED_ENVELOPE,
        )
        .expect("独立向量应成功开启");

        assert_eq!(&plaintext[..], b"Kelivo record envelope v1");
    }
}
