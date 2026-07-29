use hmac::{
    Hmac, KeyInit as HmacKeyInit, Mac,
    digest::{FixedOutput, Output},
};
use sha2_device::Sha256;
use zeroize::Zeroizing;

const SHA256_OUTPUT_LENGTH: usize = 32;
const HKDF_FIRST_BLOCK_INDEX: [u8; 1] = [1];

type HmacSha256 = Hmac<Sha256>;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct HkdfSha256Error;

pub(crate) fn expand_hkdf_sha256_single_block(
    salt: Option<&[u8]>,
    input_key_material: &[u8],
    info: &[u8],
    output: &mut [u8; SHA256_OUTPUT_LENGTH],
) -> Result<(), HkdfSha256Error> {
    let zero_salt = [0_u8; SHA256_OUTPUT_LENGTH];
    let mut extract =
        <HmacSha256 as HmacKeyInit>::new_from_slice(salt.unwrap_or(zero_salt.as_slice()))
            .map_err(|_| HkdfSha256Error)?;
    Mac::update(&mut extract, input_key_material);
    // 所有协议派生值恰为 SHA-256 单块；PRK 由本模块清理，T(1) 直接落入调用方的清理目标。
    let mut prk = Zeroizing::new([0_u8; SHA256_OUTPUT_LENGTH]);
    let prk_output =
        <&mut Output<HmacSha256>>::try_from(prk.as_mut_slice()).map_err(|_| HkdfSha256Error)?;
    FixedOutput::finalize_into(extract, prk_output);

    let mut expand =
        <HmacSha256 as HmacKeyInit>::new_from_slice(prk.as_slice()).map_err(|_| HkdfSha256Error)?;
    Mac::update(&mut expand, info);
    Mac::update(&mut expand, &HKDF_FIRST_BLOCK_INDEX);
    let output =
        <&mut Output<HmacSha256>>::try_from(output.as_mut_slice()).map_err(|_| HkdfSha256Error)?;
    FixedOutput::finalize_into(expand, output);
    Ok(())
}

#[cfg(test)]
mod tests {
    use zeroize::Zeroizing;

    use super::expand_hkdf_sha256_single_block;

    #[test]
    fn single_block_hkdf_matches_rfc5869_case_one() {
        let input_key_material = [0x0b; 22];
        let salt = [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c,
        ];
        let info = [0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9];
        let expected = [
            0x3c, 0xb2, 0x5f, 0x25, 0xfa, 0xac, 0xd5, 0x7a, 0x90, 0x43, 0x4f, 0x64, 0xd0, 0x36,
            0x2f, 0x2a, 0x2d, 0x2d, 0x0a, 0x90, 0xcf, 0x1a, 0x5a, 0x4c, 0x5d, 0xb0, 0x2d, 0x56,
            0xec, 0xc4, 0xc5, 0xbf,
        ];
        let mut output = Zeroizing::new([0_u8; 32]);

        expand_hkdf_sha256_single_block(Some(&salt), &input_key_material, &info, &mut output)
            .expect("RFC 5869 单块向量应可派生");

        assert_eq!(output.as_slice(), expected);
    }
}
